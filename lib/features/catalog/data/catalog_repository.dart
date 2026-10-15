import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../comparison/models/comparison_offer_page.dart';
import '../models/catalog_product.dart';
import '../models/catalog_product_page.dart';
import '../models/catalog_search_request.dart';

class CatalogRepository {
  const CatalogRepository(this._client);

  final Dio _client;

  Future<CatalogProductPage> searchProducts(
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

    try {
      final response = await _client.get<Map<String, dynamic>>(
        'api/catalog/products/',
        queryParameters: resolvedRequest.toQueryParameters(),
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      }
      return CatalogProductPage.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  Future<CatalogProduct> getProduct(
    int productId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        'api/catalog/products/$productId/',
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      }
      return CatalogProduct.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  Future<List<CatalogCategory>> getCategoryTree({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _client.get<List<dynamic>>(
        'api/catalog/categories/tree/',
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      }
      return data
          .map(
            (item) => CatalogCategory.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on ArgumentError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  Future<ComparisonOfferPage> getComparisonOffers(
    int productId, {
    int page = 1,
    int pageSize = 20,
    String? location,
    CancelToken? cancelToken,
  }) async {
    try {
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
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }
}
