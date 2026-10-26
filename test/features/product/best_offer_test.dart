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
import 'package:frontend/features/comparison/models/comparison_offer.dart';
import 'package:frontend/features/comparison/models/comparison_offer_page.dart';

/// Règle du tampon « Meilleur prix vérifié » : prix unitaire normalisé le plus
/// bas parmi au moins deux offres vérifiées, valides, récentes, non
/// promotionnelles et normalisées dans le même groupe de comparaison.
void main() {
  Future<String?> sealedMerchant(
    WidgetTester tester,
    List<ComparisonOffer> offers,
  ) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AppRouter.router.go('/product/15');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(
            _OffersRepository(offers),
          ),
          connectivityServiceProvider.overrideWithValue(_Online()),
        ],
        child: const ComparateurPrixApp(),
      ),
    );
    await tester.pumpAndSettle();
    final seal = find.byType(BestPriceSeal);
    if (seal.evaluate().isEmpty) {
      return null;
    }
    final card = find.ancestor(of: seal, matching: find.byType(Stack)).first;
    for (final offer in offers) {
      final name = find.descendant(
        of: card,
        matching: find.text(offer.merchantName!),
      );
      if (name.evaluate().isNotEmpty) {
        return offer.merchantName;
      }
    }
    return 'unknown';
  }

  testWidgets('compares unit prices, not totals of different quantities', (
    tester,
  ) async {
    final merchant = await sealedMerchant(tester, [
      _offer('Petit sac', amount: '6900', quantity: '5', unitPrice: '1380'),
      _offer('Grand sac', amount: '25000', quantity: '25', unitPrice: '1000'),
    ]);

    expect(merchant, 'Grand sac');
  });

  testWidgets('ignores promotions, stale prices and unverified prices', (
    tester,
  ) async {
    final merchant = await sealedMerchant(tester, [
      _offer('Promo', unitPrice: '900', promotion: true),
      _offer('Ancien', unitPrice: '950', freshness: 'old'),
      _offer('Non vérifié', unitPrice: '980', level: 'none'),
      _offer('Expiré', unitPrice: '990', freshness: 'expire'),
      _offer('Vérifié A', unitPrice: '1200', level: 'auto'),
      _offer('Vérifié B', unitPrice: '1100', freshness: 'very_recent'),
    ]);

    expect(merchant, 'Vérifié B');
  });

  testWidgets('no seal without two comparable offers', (tester) async {
    final merchant = await sealedMerchant(tester, [
      _offer('Seul vérifié', unitPrice: '1200'),
      _offer('Sans normalisation', unitPrice: null),
    ]);

    expect(merchant, isNull);
  });

  testWidgets('explains why a unit price is missing', (tester) async {
    await sealedMerchant(tester, [
      _offer(
        'Sans conversion',
        unitPrice: null,
        reasons: const ['no_exact_conversion_to_base_unit'],
      ),
    ]);

    expect(
      find.textContaining('Prix unitaire indisponible : pas de conversion'),
      findsOneWidget,
    );
  });
}

ComparisonOffer _offer(
  String merchant, {
  String amount = '6900',
  String quantity = '5',
  required String? unitPrice,
  bool promotion = false,
  String freshness = 'recent',
  String level = 'manual',
  List<String> reasons = const ['same_product'],
}) => ComparisonOffer(
  id: merchant.hashCode,
  product: 15,
  productName: 'Riz parfumé',
  amount: amount,
  currency: 'XAF',
  quantity: quantity,
  merchantName: merchant,
  unitCode: 'kg',
  isActive: true,
  isPromotion: promotion,
  isCurrentlyValid: true,
  comparisonReasons: reasons,
  freshness: freshness,
  verificationLevel: level,
  normalizedUnitPrice: unitPrice,
  comparisonGroup: unitPrice == null
      ? null
      : const ComparisonGroup(currency: 'XAF', unitCode: 'kg'),
);

class _Online implements ConnectivityService {
  @override
  Future<bool> hasNetwork() async => true;

  @override
  Stream<bool> get networkChanges => const Stream.empty();
}

class _OffersRepository extends CatalogRepository {
  _OffersRepository(this.offers)
    : super(Dio(), cache: OfflineCache(storage: MemoryCacheStorage()));

  final List<ComparisonOffer> offers;

  @override
  Future<RepositoryResult<CatalogProduct>> getProduct(
    int productId, {
    CancelToken? cancelToken,
  }) async => const RepositoryResult(
    value: CatalogProduct(
      id: 15,
      name: 'Riz parfumé',
      slug: 'riz',
      availability: 'available',
      isActive: true,
      isVerified: true,
    ),
  );

  @override
  Future<RepositoryResult<ComparisonOfferPage>> getComparisonOffers(
    int productId, {
    int page = 1,
    int pageSize = 20,
    String? location,
    CancelToken? cancelToken,
  }) async => RepositoryResult(
    value: ComparisonOfferPage(count: offers.length, results: offers),
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
