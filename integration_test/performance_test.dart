// Transitions d'interface locales (P0.7), sans réseau : le backend est
// simulé pour ne pas attribuer la latence réseau au rendu Flutter.
// Lancer en mode profile via test_driver/perf_driver.dart.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/core/network/connectivity.dart';
import 'package:frontend/core/storage/cache_storage.dart';
import 'package:frontend/core/storage/offline_cache.dart';
import 'package:frontend/core/storage/repository_result.dart';
import 'package:frontend/features/availability/models/merchant_availability.dart';
import 'package:frontend/features/catalog/data/catalog_providers.dart';
import 'package:frontend/features/catalog/data/catalog_repository.dart';
import 'package:frontend/features/catalog/models/catalog_product.dart';
import 'package:frontend/features/catalog/models/catalog_product_page.dart';
import 'package:frontend/features/comparison/models/comparison_offer.dart';
import 'package:frontend/features/comparison/models/comparison_offer_page.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local UI transitions', (tester) async {
    AppRouter.router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_LocalRepository()),
          connectivityServiceProvider.overrideWithValue(_Online()),
        ],
        child: const ComparateurPrixApp(),
      ),
    );
    await tester.pumpAndSettle();

    await binding.traceAction(() async {
      for (var run = 0; run < 10; run++) {
        AppRouter.router.go('/search?query=riz');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Riz parfumé 5 kg').first);
        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -600),
          2000,
        );
        await tester.pumpAndSettle();
        AppRouter.router.go('/');
        await tester.pumpAndSettle();
      }
    }, reportKey: 'ui_transitions');
  });
}

class _Online implements ConnectivityService {
  @override
  Future<bool> hasNetwork() async => true;

  @override
  Stream<bool> get networkChanges => const Stream.empty();
}

const _product = CatalogProduct(
  id: 15,
  name: 'Riz parfumé 5 kg',
  slug: 'riz',
  availability: 'available',
  isActive: true,
  isVerified: true,
  priceSnapshot: '6900',
  priceSnapshotCurrency: 'XAF',
);

class _LocalRepository extends CatalogRepository {
  _LocalRepository()
    : super(Dio(), cache: OfflineCache(storage: MemoryCacheStorage()));

  @override
  Future<List<CatalogCategory>> getCategoryTree({
    CancelToken? cancelToken,
  }) async => const [CatalogCategory(id: 1, name: 'Épicerie', slug: 'e')];

  @override
  Future<RepositoryResult<CatalogProductPage>> searchProducts(
    dynamic request, {
    CancelToken? cancelToken,
  }) async => const RepositoryResult(
    value: CatalogProductPage(count: 1, results: [_product]),
  );

  @override
  Future<RepositoryResult<CatalogProduct>> getProduct(
    int productId, {
    CancelToken? cancelToken,
  }) async => const RepositoryResult(value: _product);

  @override
  Future<RepositoryResult<ComparisonOfferPage>> getComparisonOffers(
    int productId, {
    int page = 1,
    int pageSize = 20,
    String? location,
    CancelToken? cancelToken,
  }) async => RepositoryResult(
    value: ComparisonOfferPage(
      count: 6,
      results: [
        for (var i = 0; i < 6; i++)
          ComparisonOffer(
            id: i,
            product: 15,
            productName: _product.name,
            amount: '${6900 + i * 150}',
            currency: 'XAF',
            quantity: '5',
            merchantName: 'Magasin $i',
            unitSymbol: 'kg',
            isActive: true,
            isPromotion: false,
            isCurrentlyValid: true,
            comparisonReasons: const ['same_product'],
            freshness: 'recent',
            verificationLevel: 'official',
            normalizedUnitPrice: '${(6900 + i * 150) / 5}',
            comparisonGroup: const ComparisonGroup(
              currency: 'XAF',
              unitCode: 'kg',
            ),
          ),
      ],
    ),
  );

  @override
  Future<RepositoryResult<MerchantAvailabilityPage>> getProductAvailability(
    int productId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async => const RepositoryResult(
    value: MerchantAvailabilityPage(count: 0, results: []),
  );
}
