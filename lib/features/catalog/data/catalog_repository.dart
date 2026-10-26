import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/storage/repository_result.dart';
import '../../availability/models/merchant_availability.dart';
import '../../comparison/models/comparison_offer_page.dart';
import '../models/catalog_product.dart';
import '../models/catalog_product_page.dart';
import '../models/catalog_search_request.dart';

class CatalogRepository {
  CatalogRepository(
    this._client, {
    OfflineCache? cache,
    Future<bool> Function()? hasNetwork,
  }) : _cache = cache ?? OfflineCache(),
       _hasNetwork = hasNetwork ?? _assumeNetwork;

  final Dio _client;
  final OfflineCache _cache;

  /// Distingue « hors ligne » de « serveur injoignable ».
  final Future<bool> Function() _hasNetwork;

  static Future<bool> _assumeNetwork() async => true;

  Future<RepositoryResult<CatalogProductPage>> searchProducts(
    dynamic request, {
    CancelToken? cancelToken,
  }) async {
    final CatalogSearchRequest resolvedRequest;
    if (request is CatalogSearchRequest) {
      resolvedRequest = request;
    } else if (request is String) {
      resolvedRequest = CatalogSearchRequest(query: request.trim());
    } else {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }

    final parameters = resolvedRequest.toQueryParameters();
    final pageNumber = resolvedRequest.page;
    return _fetchWithCache(
      key:
          'catalog-search:${base64Url.encode(utf8.encode(jsonEncode(parameters)))}:$pageNumber',
      fetch: () async {
        final response = await _client.get<Map<String, dynamic>>(
          'api/catalog/products/',
          queryParameters: parameters,
          cancelToken: cancelToken,
        );
        final data = response.data;
        if (data == null) {
          throw const ApiException(kind: ApiErrorKind.invalidResponse);
        }
        return CatalogProductPage.fromJson(data);
      },
      encode: (page) => page.toJson(),
      decode: CatalogProductPage.fromJson,
    );
  }

  Future<RepositoryResult<CatalogProduct>> getProduct(
    int productId, {
    CancelToken? cancelToken,
  }) async {
    return _fetchWithCache(
      key: 'catalog-product:$productId',
      fetch: () async {
        final response = await _client.get<Map<String, dynamic>>(
          'api/catalog/products/$productId/',
          cancelToken: cancelToken,
        );
        final data = response.data;
        if (data == null) {
          throw const ApiException(kind: ApiErrorKind.invalidResponse);
        }
        return CatalogProduct.fromJson(data);
      },
      encode: (product) => product.toJson(),
      decode: CatalogProduct.fromJson,
    );
  }

  /// Arbre des catégories (non paginé), mis en cache comme les autres
  /// lectures pour rester disponible hors ligne.
  Future<List<CatalogCategory>> getCategoryTree({
    CancelToken? cancelToken,
  }) async {
    try {
      final result = await _fetchWithCache<List<CatalogCategory>>(
        key: 'catalog-categories-tree',
        fetch: () async {
          final response = await _client.get<List<dynamic>>(
            'api/catalog/categories/tree/',
            cancelToken: cancelToken,
          );
          final data = response.data;
          if (data == null) {
            throw const ApiException(kind: ApiErrorKind.invalidResponse);
          }
          return _decodeCategories(data);
        },
        encode: (tree) => {
          'items': [for (final category in tree) category.toJson()],
        },
        decode: (json) => _decodeCategories(json['items'] as List<dynamic>),
      );
      return result.value;
    } on ArgumentError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  static List<CatalogCategory> _decodeCategories(List<dynamic> data) => data
      .map(
        (item) =>
            CatalogCategory.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList(growable: false);

  Future<RepositoryResult<ComparisonOfferPage>> getComparisonOffers(
    int productId, {
    int page = 1,
    int pageSize = 20,
    String? location,
    CancelToken? cancelToken,
  }) async {
    return _fetchWithCache(
      key: 'comparison-offers:$productId:$page:$pageSize:${location ?? ''}',
      fetch: () async {
        final response = await _client.get<Map<String, dynamic>>(
          'api/comparison/products/$productId/offers/',
          queryParameters: {
            'page': page,
            'page_size': pageSize,
            if (location != null && location.isNotEmpty) 'location': location,
          },
          cancelToken: cancelToken,
        );
        final data = response.data;
        if (data == null) {
          throw const ApiException(kind: ApiErrorKind.invalidResponse);
        }
        return ComparisonOfferPage.fromJson(data);
      },
      encode: (offers) => offers.toJson(),
      decode: ComparisonOfferPage.fromJson,
    );
  }

  /// Disponibilité publique du produit chez chaque marchand
  /// (`GET /api/availability/?product={id}`), la plus récente d'abord.
  Future<RepositoryResult<MerchantAvailabilityPage>> getProductAvailability(
    int productId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return _fetchWithCache(
      key: 'availability:$productId:$page:$pageSize',
      fetch: () async {
        final response = await _client.get<Map<String, dynamic>>(
          'api/availability/',
          queryParameters: {
            'product': productId,
            'page': page,
            'page_size': pageSize,
          },
          cancelToken: cancelToken,
        );
        final data = response.data;
        if (data == null) {
          throw const ApiException(kind: ApiErrorKind.invalidResponse);
        }
        return MerchantAvailabilityPage.fromJson(data);
      },
      encode: (availability) => availability.toJson(),
      decode: MerchantAvailabilityPage.fromJson,
    );
  }

  Future<void> clearOfflineCache() => _cache.clear();

  Future<RepositoryResult<T>> _fetchWithCache<T>({
    required String key,
    required Future<T> Function() fetch,
    required Map<String, dynamic> Function(T) encode,
    required T Function(Map<String, dynamic>) decode,
  }) async {
    try {
      final value = await fetch();
      await _cache.write(key, encode(value));
      return RepositoryResult(value: value);
    } on DioException catch (error) {
      final apiError = await _classify(error);
      if (!_canUseCache(apiError)) {
        throw apiError;
      }
      final cached = await _cache.read(key);
      if (cached == null) {
        throw apiError;
      }
      try {
        return RepositoryResult(
          value: decode(cached.value),
          cachedAtUtc: cached.cachedAtUtc,
          isExpired: cached.isExpired,
        );
      } on FormatException {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      } on TypeError {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      }
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  Future<ApiException> _classify(DioException error) async {
    final apiError = ApiException.fromDio(error);
    if (apiError.kind != ApiErrorKind.network ||
        error.type == DioExceptionType.cancel ||
        await _hasNetwork()) {
      return apiError;
    }
    return const ApiException(kind: ApiErrorKind.offline);
  }

  bool _canUseCache(ApiException error) =>
      error.kind == ApiErrorKind.offline ||
      error.kind == ApiErrorKind.network ||
      error.kind == ApiErrorKind.timeout ||
      (error.kind == ApiErrorKind.http &&
          error.statusCode != null &&
          // 429: rate limited; a local copy beats an error screen.
          (error.statusCode! >= 500 || error.statusCode == 429));
}
