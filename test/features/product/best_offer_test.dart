import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/no_evolution.dart';

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

/// Le tampon « Meilleur prix vérifié » suit `is_best_offer`, choisi par le
/// serveur (apps/comparison/ranking.py, contrat P0.4) : l'app ne le recalcule
/// plus. La ligne de preuve affiche le verdict et la phrase de l'API.
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
          noPriceEvolution,
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

  testWidgets('the seal follows the offer the server chose', (tester) async {
    // The cheaper promotion is ranked first but does not get the label.
    final merchant = await sealedMerchant(tester, [
      _offer('Promo', unitPrice: '900', promotion: true),
      _offer('Vérifié', unitPrice: '1100', best: true),
    ]);

    expect(merchant, 'Vérifié');
  });

  testWidgets('no seal when the server gives none', (tester) async {
    final merchant = await sealedMerchant(tester, [
      _offer('Seul vérifié', unitPrice: '1200'),
      _offer('Sans normalisation', unitPrice: null),
    ]);

    expect(merchant, isNull);
  });

  testWidgets('the proof line shows the verdict and the API sentence', (
    tester,
  ) async {
    await sealedMerchant(tester, [
      _offer(
        'Vérifié',
        unitPrice: '1100',
        trust: const PriceTrust(
          freshnessLevel: 'fresh',
          freshnessLabel: 'Très récent',
          confidenceLevel: 'high',
          confidenceLabel: 'Confiance élevée',
          verdict: 'to_confirm',
          verdictLabel: 'Prix à confirmer',
          explanation: 'Confirmé il y a 2 h, vérifié par un modérateur.',
        ),
      ),
    ]);

    expect(
      find.textContaining(
        'Plutôt fiable · Confirmé il y a 2 h',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // The app no longer builds its own freshness and verification badges.
    expect(find.textContaining('Fraîcheur :'), findsNothing);
  });

  test('an offer reads the ranking and trust of the API', () {
    final offer = ComparisonOffer.fromJson({
      'id': 1,
      'product': 15,
      'product_name': 'Riz',
      'amount': '1100',
      'currency': 'XAF',
      'quantity': '1',
      'is_active': true,
      'is_promotion': false,
      'is_currently_valid': true,
      'comparison_reasons': <String>[],
      'rank': 1,
      'is_best_offer': true,
      'offer_status': 'current',
      'last_confirmed_at': '2026-11-13T08:00:00Z',
      'trust': {
        'freshness_level': 'fresh',
        'freshness_label': 'Très récent',
        'freshness_reference_at': '2026-11-13T08:00:00Z',
        'confidence_level': 'high',
        'confidence_label': 'Confiance élevée',
        'verdict': 'reliable',
        'verdict_label': 'Prix fiable',
        'explanation': 'Confirmé il y a 2 h, vérifié par un modérateur.',
      },
    });

    expect(offer.rank, 1);
    expect(offer.isBestOffer, isTrue);
    expect(offer.offerStatus, OfferStatus.current);
    expect(offer.trust?.verdict, 'reliable');
    expect(offer.trust?.freshnessReferenceAt, isNotNull);
  });

  test('an older answer without ranking still reads', () {
    final offer = ComparisonOffer.fromJson({
      'id': 1,
      'product': 15,
      'product_name': 'Riz',
      'amount': '1100',
      'currency': 'XAF',
      'quantity': '1',
      'is_active': true,
      'is_promotion': false,
      'is_currently_valid': true,
      'comparison_reasons': <String>[],
    });

    expect(offer.isBestOffer, isFalse);
    expect(offer.rank, isNull);
    expect(offer.trust, isNull);
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
  bool best = false,
  PriceTrust? trust,
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
  isBestOffer: best,
  trust: trust,
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
