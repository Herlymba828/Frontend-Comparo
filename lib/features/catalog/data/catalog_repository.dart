import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../models/catalog_product_page.dart';

class CatalogRepository {
  const CatalogRepository(this._client);

  final Dio _client;

  Future<CatalogProductPage> searchProducts(
    String query, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        'api/catalog/products/',
        queryParameters: {
          'q': query,
          'page': 1,
          'page_size': 20,
        },
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
}
