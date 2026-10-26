// Parcours critiques de bout en bout avec un backend simulé et déterministe
// (P4.6, P6.1). Exécution : flutter test integration_test/critical_journeys_test.dart -d <appareil>
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/core/widgets/market_widgets.dart';
import 'package:frontend/core/errors/api_exception.dart';
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> launch(
    WidgetTester tester,
    _JourneyRepository repository,
  ) async {
    AppRouter.router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(_Connectivity()),
        ],
        child: const ComparateurPrixApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search → product → comparison → availability', (tester) async {
    await launch(tester, _JourneyRepository());

    expect(find.text('Prix du jour'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, 'riz');
    await tester.tap(find.byTooltip('Rechercher').first);
    await tester.pumpAndSettle();

    expect(find.text('Recherche de produit'), findsOneWidget);
    await tester.tap(find.text('Riz parfumé 5 kg'));
    await tester.pumpAndSettle();

    expect(find.text('Comparaison d’offres'), findsOneWidget);
    expect(find.text('Prix comparés en XAF / kg'), findsOneWidget);
    expect(find.byType(BestPriceSeal), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Stock limité'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Disponibilité chez les marchands'), findsOneWidget);
  });

  testWidgets('offline: expired cached data stays visible and is labelled', (
    tester,
  ) async {
    await launch(tester, _JourneyRepository(offline: true));
    AppRouter.router.go('/product/15');
    await tester.pumpAndSettle();

    expect(find.text('Riz parfumé 5 kg'), findsOneWidget);
    expect(find.textContaining('Cache expiré'), findsWidgets);
    expect(find.textContaining('non vérifiées'), findsWidgets);
  });

  testWidgets('partial failure keeps the product and offers a retry', (
    tester,
  ) async {
    final repository = _JourneyRepository(offersFail: true);
    await launch(tester, repository);
    AppRouter.router.go('/product/15');
    await tester.pumpAndSettle();

    expect(find.text('Riz parfumé 5 kg'), findsOneWidget);
    expect(find.textContaining('serveur est injoignable'), findsOneWidget);

    repository.offersFail = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Magasin A'), findsOneWidget);
  });
}

class _Connectivity implements ConnectivityService {
  @override
  Future<bool> hasNetwork() async => true;

  @override
  Stream<bool> get networkChanges => const Stream.empty();
}

const _product = CatalogProduct(
  id: 15,
  name: 'Riz parfumé 5 kg',
  slug: 'riz-parfume-5kg',
  availability: 'available',
  isActive: true,
  isVerified: true,
  priceSnapshot: '6900',
  priceSnapshotCurrency: 'XAF',
);

ComparisonOffer _offer(int id, String merchant, String amount) =>
    ComparisonOffer(
      id: id,
      product: 15,
      productName: _product.name,
      amount: amount,
      currency: 'XAF',
      quantity: '5',
      merchantName: merchant,
      unitSymbol: 'kg',
      isActive: true,
      isPromotion: false,
      isCurrentlyValid: true,
      comparisonReasons: const ['same_product'],
      verificationLevel: 'manual',
      freshness: 'very_recent',
      normalizedUnitPrice: (double.parse(amount) / 5).toStringAsFixed(6),
      comparisonGroup: const ComparisonGroup(currency: 'XAF', unitCode: 'kg'),
    );

class _JourneyRepository extends CatalogRepository {
  _JourneyRepository({this.offline = false, this.offersFail = false})
    : super(Dio(), cache: OfflineCache(storage: MemoryCacheStorage()));

  final bool offline;
  bool offersFail;

  RepositoryResult<T> _result<T>(T value) => offline
      ? RepositoryResult(
          value: value,
          cachedAtUtc: DateTime.now().toUtc().subtract(const Duration(days: 8)),
          isExpired: true,
        )
      : RepositoryResult(value: value);

  @override
  Future<List<CatalogCategory>> getCategoryTree({
    CancelToken? cancelToken,
  }) async => const [];

  @override
  Future<RepositoryResult<CatalogProductPage>> searchProducts(
    dynamic request, {
    CancelToken? cancelToken,
  }) async => _result(const CatalogProductPage(count: 1, results: [_product]));

  @override
  Future<RepositoryResult<CatalogProduct>> getProduct(
    int productId, {
    CancelToken? cancelToken,
  }) async => _result(_product);

  @override
  Future<RepositoryResult<ComparisonOfferPage>> getComparisonOffers(
    int productId, {
    int page = 1,
    int pageSize = 20,
    String? location,
    CancelToken? cancelToken,
  }) async {
    if (offersFail) {
      throw const ApiException(kind: ApiErrorKind.network);
    }
    return _result(
      ComparisonOfferPage(
        count: 2,
        results: [
          _offer(1, 'Magasin A', '6900'),
          _offer(2, 'Magasin B', '7250'),
        ],
      ),
    );
  }

  @override
  Future<RepositoryResult<MerchantAvailabilityPage>> getProductAvailability(
    int productId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async => _result(
    const MerchantAvailabilityPage(
      count: 1,
      results: [
        MerchantAvailability(
          id: 1,
          product: 15,
          merchantName: 'Magasin A',
          status: 'limited',
          isAvailable: true,
        ),
      ],
    ),
  );
}
