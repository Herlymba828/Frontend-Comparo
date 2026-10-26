import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/storage/cache_storage.dart';
import 'package:frontend/core/storage/offline_cache.dart';
import 'package:frontend/features/catalog/data/catalog_repository.dart';
import 'package:frontend/features/catalog/models/catalog_search_request.dart';

void main() {
  test(
    'search sends the public catalogue query and pagination parameters',
    () async {
      final adapter = _ResponseAdapter(_productPage);
      final repository = CatalogRepository(
        Dio(BaseOptions(baseUrl: 'http://localhost:8010/'))
          ..httpClientAdapter = adapter,
        cache: OfflineCache(storage: MemoryCacheStorage()),
      );

      final result = await repository.searchProducts('café noir');

      expect(result.value.results.single.name, 'Café noir');
      expect(adapter.request!.uri.path, '/api/catalog/products/');
      expect(adapter.request!.queryParameters, {
        'q': 'café noir',
        'page': 1,
        'page_size': 20,
      });
    },
  );

  test(
    'search sends active filters, ordering and the requested page',
    () async {
      final adapter = _ResponseAdapter(_productPage);
      final repository = CatalogRepository(
        Dio(BaseOptions(baseUrl: 'http://localhost:8010/'))
          ..httpClientAdapter = adapter,
        cache: OfflineCache(storage: MemoryCacheStorage()),
      );

      await repository.searchProducts(
        const CatalogSearchRequest(
          query: 'café',
          category: 'boissons',
          available: true,
          verified: true,
          ordering: '-price_snapshot',
          page: 2,
          pageSize: 20,
        ),
      );

      expect(adapter.request!.queryParameters, {
        'q': 'café',
        'page': 2,
        'page_size': 20,
        'category': 'boissons',
        'available': 'true',
        'verified': 'true',
        'ordering': '-price_snapshot',
      });
    },
  );

  test(
    'falls back to the last cached response when the API is unavailable',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8010/'));
      dio.httpClientAdapter = _ResponseAdapter(_productPage);
      final repository = CatalogRepository(
        dio,
        cache: OfflineCache(storage: MemoryCacheStorage()),
      );

      final fresh = await repository.searchProducts('café noir');
      dio.httpClientAdapter = _ResponseAdapter({}, statusCode: 503);
      final cached = await repository.searchProducts('café noir');

      expect(fresh.isFromCache, isFalse);
      expect(cached.isFromCache, isTrue);
      expect(cached.value.results.single.name, 'Café noir');
    },
  );

  test(
    'maps a backend validation envelope without losing its error code',
    () async {
      final adapter = _ResponseAdapter({
        'error': {
          'code': 'invalid_filter',
          'fields': {
            'q': ['Invalid'],
          },
        },
      }, statusCode: 400);
      final repository = CatalogRepository(
        Dio(BaseOptions(baseUrl: 'http://localhost:8010/'))
          ..httpClientAdapter = adapter,
        cache: OfflineCache(storage: MemoryCacheStorage()),
      );

      await expectLater(
        repository.searchProducts('café'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', ApiErrorKind.http)
              .having((error) => error.statusCode, 'statusCode', 400)
              .having((error) => error.code, 'code', 'invalid_filter')
              .having((error) => error.fields, 'fields', isNotNull),
        ),
      );
    },
  );
}

final _productPage = <String, dynamic>{
  'count': 1,
  'next': null,
  'previous': null,
  'results': [
    {
      'id': 7,
      'name': 'Café noir',
      'slug': 'cafe-noir',
      'category': null,
      'brand': null,
      'default_unit': null,
      'image_url': '',
      'price_snapshot': '890.00',
      'price_snapshot_currency': 'XAF',
      'price_snapshot_updated_at': null,
      'availability': 'unknown',
      'is_active': true,
      'is_verified': false,
    },
  ],
};

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.body, {this.statusCode = 200});

  final Object body;
  final int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final responseText = jsonEncode(body);
    return ResponseBody.fromString(
      responseText,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
