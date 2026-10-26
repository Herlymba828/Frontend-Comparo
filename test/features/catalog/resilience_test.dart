import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/network/connectivity.dart';
import 'package:frontend/core/storage/cache_storage.dart';
import 'package:frontend/core/storage/offline_cache.dart';
import 'package:frontend/core/storage/repository_result.dart';
import 'package:frontend/features/catalog/data/catalog_providers.dart';
import 'package:frontend/features/catalog/data/catalog_repository.dart';
import 'package:frontend/features/catalog/models/catalog_product.dart';
import 'package:frontend/features/catalog/models/catalog_product_page.dart';
import 'package:frontend/features/catalog/models/catalog_search_request.dart';

void main() {
  group('network failures', () {
    CatalogRepository repository(
      HttpClientAdapter adapter, {
      required bool hasNetwork,
      OfflineCache? cache,
    }) => CatalogRepository(
      Dio(BaseOptions(baseUrl: 'http://localhost:8010/'))
        ..httpClientAdapter = adapter,
      cache: cache ?? OfflineCache(storage: MemoryCacheStorage()),
      hasNetwork: () async => hasNetwork,
    );

    test('no device network is reported as offline', () async {
      final repo = repository(
        _FailingAdapter(DioExceptionType.connectionError),
        hasNetwork: false,
      );

      await expectLater(
        repo.getProduct(15),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.offline,
          ),
        ),
      );
    });

    test(
      'a network without server answer is reported as unreachable',
      () async {
        final repo = repository(
          _FailingAdapter(DioExceptionType.connectionError),
          hasNetwork: true,
        );

        await expectLater(
          repo.getProduct(15),
          throwsA(
            isA<ApiException>().having(
              (error) => error.kind,
              'kind',
              ApiErrorKind.network,
            ),
          ),
        );
      },
    );

    test('a slow server is reported as a timeout', () async {
      final repo = repository(
        _FailingAdapter(DioExceptionType.receiveTimeout),
        hasNetwork: false,
      );

      await expectLater(
        repo.getProduct(15),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.timeout,
          ),
        ),
      );
    });

    test('offline reads fall back to the cached copy', () async {
      final cache = OfflineCache(storage: MemoryCacheStorage());
      final online = repository(
        _JsonAdapter(_product),
        hasNetwork: true,
        cache: cache,
      );
      await online.getProduct(15);

      final offline = repository(
        _FailingAdapter(DioExceptionType.connectionError),
        hasNetwork: false,
        cache: cache,
      );
      final result = await offline.getProduct(15);

      expect(result.isFromCache, isTrue);
      expect(result.value.name, 'Riz parfumé');
    });

    test('offline user messages differ from server errors', () {
      expect(
        const ApiException(kind: ApiErrorKind.offline).userMessage,
        contains('hors ligne'),
      );
      expect(
        const ApiException(kind: ApiErrorKind.network).userMessage,
        contains('serveur'),
      );
    });
  });

  group('availability', () {
    test('requests the public availability of one product', () async {
      final adapter = _JsonAdapter({
        'count': 2,
        'next': null,
        'previous': null,
        'results': [
          {
            'id': 3,
            'product': 15,
            'product_name': 'Riz parfumé',
            'merchant': 4,
            'merchant_name': 'Supermarché local',
            'location': 9,
            'status': 'limited',
            'is_available': true,
            'quantity_available': '3.000',
            'observed_at': '2026-06-04T10:00:00Z',
            'updated_at': '2026-06-04T10:05:00Z',
          },
          {'id': 4, 'product': 15, 'status': 'unknown', 'is_available': false},
        ],
      });
      final repo = CatalogRepository(
        Dio(BaseOptions(baseUrl: 'http://localhost:8010/'))
          ..httpClientAdapter = adapter,
        cache: OfflineCache(storage: MemoryCacheStorage()),
      );

      final result = await repo.getProductAvailability(15);

      expect(adapter.request?.path, 'api/availability/');
      expect(adapter.request?.queryParameters, {
        'product': 15,
        'page': 1,
        'page_size': 20,
      });
      final records = result.value.results;
      expect(records.first.status, 'limited');
      expect(records.first.quantityAvailable, '3.000');
      expect(records.last.merchantName, isNull);
      expect(records.last.quantityAvailable, isNull);
      expect(records.last.observedAt, isNull);
    });
  });

  group('reconnection', () {
    test('refreshes cached results once the network is back', () async {
      final connectivity = _FakeConnectivity();
      final repo = _CountingRepository(fromCache: true);
      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
          catalogRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        productDetailsProvider(15),
        (_, _) {},
      );
      addTearDown(subscription.close);
      container.listen(reconnectProvider, (_, _) {});

      await container.read(productDetailsProvider(15).future);
      expect(repo.productCalls, 1);

      connectivity.emit(false);
      connectivity.emit(true);
      await Future<void>.delayed(Duration.zero);
      expect(repo.productCalls, 1, reason: 'debounced');

      await Future<void>.delayed(
        reconnectDebounce + const Duration(milliseconds: 100),
      );
      await container.read(productDetailsProvider(15).future);
      expect(repo.productCalls, 2);
    });

    test('does not refetch fresh results on reconnection', () async {
      final connectivity = _FakeConnectivity();
      final repo = _CountingRepository(fromCache: false);
      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
          catalogRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        productDetailsProvider(15),
        (_, _) {},
      );
      addTearDown(subscription.close);
      container.listen(reconnectProvider, (_, _) {});
      await container.read(productDetailsProvider(15).future);

      connectivity.emit(false);
      connectivity.emit(true);
      await Future<void>.delayed(
        reconnectDebounce + const Duration(milliseconds: 100),
      );

      expect(repo.productCalls, 1);
    });

    test('a short network flap does not trigger a refresh', () async {
      final connectivity = _FakeConnectivity();
      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(connectivity),
        ],
      );
      addTearDown(container.dispose);
      final events = <int>[];
      container.listen(reconnectProvider, (_, next) => events.add(next));

      connectivity.emit(false);
      connectivity.emit(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      connectivity.emit(false);
      await Future<void>.delayed(
        reconnectDebounce + const Duration(milliseconds: 100),
      );

      expect(events, isEmpty);
    });
  });

  test(
    'a superseded search is cancelled and cannot overwrite results',
    () async {
      final repo = _SlowSearchRepository();
      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
          catalogRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      const first = CatalogSearchRequest(query: 'riz');
      const second = CatalogSearchRequest(query: 'huile');

      final oldSubscription = container.listen(
        searchProductsProvider(first),
        (_, _) {},
      );
      final newSubscription = container.listen(
        searchProductsProvider(second),
        (_, _) {},
      );
      addTearDown(newSubscription.close);
      oldSubscription.close();
      await Future<void>.delayed(Duration.zero);

      expect(repo.tokens['riz']?.isCancelled, isTrue);
      repo.complete('huile');
      repo.complete('riz');
      final current = await container.read(
        searchProductsProvider(second).future,
      );
      expect(current.value.results.single.name, 'huile');
    },
  );
}

const _product = {
  'id': 15,
  'name': 'Riz parfumé',
  'slug': 'riz-parfume',
  'availability': 'available',
  'is_active': true,
  'is_verified': true,
};

class _FakeConnectivity implements ConnectivityService {
  final _changes = StreamController<bool>.broadcast(sync: true);

  void emit(bool online) => _changes.add(online);

  @override
  Future<bool> hasNetwork() async => true;

  @override
  Stream<bool> get networkChanges => _changes.stream;
}

class _CountingRepository extends CatalogRepository {
  _CountingRepository({required this.fromCache})
    : super(Dio(), cache: OfflineCache(storage: MemoryCacheStorage()));

  final bool fromCache;
  var productCalls = 0;

  @override
  Future<RepositoryResult<CatalogProduct>> getProduct(
    int productId, {
    CancelToken? cancelToken,
  }) async {
    productCalls++;
    return RepositoryResult(
      value: CatalogProduct.fromJson(_product),
      cachedAtUtc: fromCache ? DateTime.utc(2026, 10, 1) : null,
    );
  }
}

class _SlowSearchRepository extends CatalogRepository {
  _SlowSearchRepository()
    : super(Dio(), cache: OfflineCache(storage: MemoryCacheStorage()));

  final tokens = <String, CancelToken?>{};
  final _pending = <String, Completer<RepositoryResult<CatalogProductPage>>>{};

  void complete(String query) => _pending[query]?.complete(
    RepositoryResult(
      value: CatalogProductPage(
        count: 1,
        results: [
          CatalogProduct.fromJson({..._product, 'name': query}),
        ],
      ),
    ),
  );

  @override
  Future<RepositoryResult<CatalogProductPage>> searchProducts(
    dynamic request, {
    CancelToken? cancelToken,
  }) {
    final query = (request as CatalogSearchRequest).query;
    tokens[query] = cancelToken;
    return (_pending[query] = Completer()).future;
  }
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final Object body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.type);

  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException(requestOptions: options, type: type);

  @override
  void close({bool force = false}) {}
}
