import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../models/catalog_product_page.dart';
import 'catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

final searchProductsProvider =
    FutureProvider.autoDispose.family<CatalogProductPage, String>((ref, query) {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  return ref
      .watch(catalogRepositoryProvider)
      .searchProducts(query, cancelToken: cancelToken);
});
