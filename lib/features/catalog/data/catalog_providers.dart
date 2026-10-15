import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../comparison/models/comparison_offer_page.dart';
import '../models/catalog_product.dart';
import '../models/catalog_product_page.dart';
import '../models/catalog_search_request.dart';
import 'catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

final searchProductsProvider =
    FutureProvider.autoDispose
        .family<CatalogProductPage, CatalogSearchRequest>((ref, request) {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  return ref.watch(catalogRepositoryProvider).searchProducts(
        request,
        cancelToken: cancelToken,
      );
});

final productDetailsProvider =
    FutureProvider.autoDispose.family<CatalogProduct, int>((ref, productId) {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  return ref
      .watch(catalogRepositoryProvider)
      .getProduct(productId, cancelToken: cancelToken);
});

final categoryTreeProvider =
    FutureProvider.autoDispose<List<CatalogCategory>>((ref) {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  return ref
      .watch(catalogRepositoryProvider)
      .getCategoryTree(cancelToken: cancelToken);
});

final comparisonOffersProvider = FutureProvider.autoDispose
    .family<ComparisonOfferPage, ({int productId, String? location})>((ref, args) {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  return ref.watch(catalogRepositoryProvider).getComparisonOffers(
        args.productId,
        location: args.location,
        cancelToken: cancelToken,
      );
});
