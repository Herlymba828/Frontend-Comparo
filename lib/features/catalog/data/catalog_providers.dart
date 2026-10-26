import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../core/network/connectivity.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/storage/repository_result.dart';
import '../../availability/models/merchant_availability.dart';
import '../../comparison/models/comparison_offer_page.dart';
import '../models/catalog_product.dart';
import '../models/catalog_product_page.dart';
import '../models/catalog_search_request.dart';
import 'catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return CatalogRepository(
    ref.watch(apiClientProvider),
    cache: ref.watch(offlineCacheProvider),
    hasNetwork: connectivity.hasNetwork,
  );
});

final offlineCacheProvider = Provider<OfflineCache>((ref) => OfflineCache());

/// Lecture avec annulation à la libération et actualisation au retour du
/// réseau lorsque la valeur affichée vient du cache ou a échoué.
Future<RepositoryResult<T>> _cachedRead<T>(
  Ref ref,
  Future<RepositoryResult<T>> Function(CancelToken cancelToken) read,
) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  var needsRefresh = true;
  refreshOnReconnect(ref, () => needsRefresh);
  final result = await read(cancelToken);
  needsRefresh = result.isFromCache;
  return result;
}

final searchProductsProvider = FutureProvider.autoDispose
    .family<RepositoryResult<CatalogProductPage>, CatalogSearchRequest>(
      (ref, request) => _cachedRead(
        ref,
        (cancelToken) => ref
            .watch(catalogRepositoryProvider)
            .searchProducts(request, cancelToken: cancelToken),
      ),
    );

final productDetailsProvider = FutureProvider.autoDispose
    .family<RepositoryResult<CatalogProduct>, int>(
      (ref, productId) => _cachedRead(
        ref,
        (cancelToken) => ref
            .watch(catalogRepositoryProvider)
            .getProduct(productId, cancelToken: cancelToken),
      ),
    );

final categoryTreeProvider = FutureProvider.autoDispose<List<CatalogCategory>>((
  ref,
) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  var failed = true;
  refreshOnReconnect(ref, () => failed);
  final tree = await ref
      .watch(catalogRepositoryProvider)
      .getCategoryTree(cancelToken: cancelToken);
  failed = false;
  return tree;
});

final comparisonOffersProvider = FutureProvider.autoDispose
    .family<
      RepositoryResult<ComparisonOfferPage>,
      ({int productId, String? location, int page})
    >(
      (ref, args) => _cachedRead(
        ref,
        (cancelToken) => ref
            .watch(catalogRepositoryProvider)
            .getComparisonOffers(
              args.productId,
              page: args.page,
              location: args.location,
              cancelToken: cancelToken,
            ),
      ),
    );

final productAvailabilityProvider = FutureProvider.autoDispose
    .family<RepositoryResult<MerchantAvailabilityPage>, int>(
      (ref, productId) => _cachedRead(
        ref,
        (cancelToken) => ref
            .watch(catalogRepositoryProvider)
            .getProductAvailability(productId, cancelToken: cancelToken),
      ),
    );
