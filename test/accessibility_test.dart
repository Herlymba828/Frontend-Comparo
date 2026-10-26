import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/core/widgets/market_widgets.dart';
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

/// Recette P6.2 : petits et grands écrans, texte agrandi, cibles tactiles,
/// libellés et contraste ; les statuts restent lisibles sans la couleur.
void main() {
  Future<void> pumpRoute(
    WidgetTester tester,
    String route, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AppRouter.router.go(route);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_A11yRepository()),
          connectivityServiceProvider.overrideWithValue(_OnlineConnectivity()),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const ComparateurPrixApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final route in ['/', '/search?query=riz', '/product/15']) {
    for (final (label, size, scale) in [
      ('small phone, 200 % text', const Size(320, 640), 2.0),
      ('tablet', const Size(1024, 1366), 1.0),
    ]) {
      testWidgets('$route renders without overflow on $label', (tester) async {
        await pumpRoute(tester, route, size: size, textScale: scale);
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: error is FlutterError ? error.toStringDeep() : null,
        );
      });
    }

    testWidgets('$route meets tap target, label and contrast guidelines', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpRoute(tester, route);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  testWidgets('offer and availability statuses are spelled out', (
    tester,
  ) async {
    await pumpRoute(tester, '/product/15', size: const Size(390, 2400));

    expect(find.text('Offre valide'), findsOneWidget);
    expect(find.text('Stock limité'), findsOneWidget);
    expect(find.textContaining('Prix : Vérifié'), findsOneWidget);
    expect(find.byType(BestPriceSeal), findsNothing);
  });
}

class _OnlineConnectivity implements ConnectivityService {
  @override
  Future<bool> hasNetwork() async => true;

  @override
  Stream<bool> get networkChanges => const Stream.empty();
}

const _product = CatalogProduct(
  id: 15,
  name: 'Riz parfumé de qualité supérieure, sac familial de 5 kg',
  slug: 'riz-parfume',
  availability: 'available',
  isActive: true,
  isVerified: true,
  priceSnapshot: '6900',
  priceSnapshotCurrency: 'XAF',
  category: CatalogCategory(id: 1, name: 'Épicerie', slug: 'epicerie'),
  brand: CatalogBrand(id: 2, name: 'Marque exemple', slug: 'marque'),
  description: 'Riz long grain parfumé.',
);

class _A11yRepository extends CatalogRepository {
  _A11yRepository()
    : super(Dio(), cache: OfflineCache(storage: MemoryCacheStorage()));

  @override
  Future<List<CatalogCategory>> getCategoryTree({
    CancelToken? cancelToken,
  }) async => const [
    CatalogCategory(id: 1, name: 'Épicerie', slug: 'epicerie'),
    CatalogCategory(id: 2, name: 'Boissons et jus de fruits', slug: 'b'),
  ];

  @override
  Future<RepositoryResult<CatalogProductPage>> searchProducts(
    dynamic request, {
    CancelToken? cancelToken,
  }) async => const RepositoryResult(
    value: CatalogProductPage(count: 2, results: [_product, _product]),
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
      count: 1,
      results: [
        ComparisonOffer(
          id: 1,
          product: 15,
          productName: _product.name,
          amount: '6900',
          currency: 'XAF',
          quantity: '5',
          merchantName: 'Magasin du centre-ville de Libreville',
          location: 'Owendo',
          unitSymbol: 'kg',
          isActive: true,
          isPromotion: false,
          isCurrentlyValid: true,
          comparisonReasons: const ['same_product'],
          availability: 'available',
          freshness: 'recent',
          verificationLevel: 'manual',
          observedAt: DateTime.utc(2026, 10, 22),
          sourceLabel: 'Relevé terrain',
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
    value: MerchantAvailabilityPage(
      count: 1,
      results: [
        MerchantAvailability(
          id: 1,
          product: 15,
          merchantName: 'Magasin du centre-ville de Libreville',
          status: 'limited',
          isAvailable: true,
        ),
      ],
    ),
  );
}
