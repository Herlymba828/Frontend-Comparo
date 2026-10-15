// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/features/catalog/data/catalog_providers.dart';
import 'package:frontend/features/catalog/data/catalog_repository.dart';
import 'package:frontend/features/catalog/models/catalog_product.dart';
import 'package:frontend/features/catalog/models/catalog_product_page.dart';
import 'package:frontend/features/catalog/models/catalog_search_request.dart';
import 'package:frontend/features/comparison/models/comparison_offer.dart';
import 'package:frontend/features/comparison/models/comparison_offer_page.dart';
import 'package:frontend/features/product/product_screen.dart';

void main() {
  testWidgets('app starts and shows home screen title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ComparateurPrixApp()));

    expect(find.text('Comparateur Prix'), findsOneWidget);
    expect(find.text('Trouver le meilleur prix'), findsOneWidget);
  });

  testWidgets('search displays products returned by the catalog repository', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
        ],
        child: const ComparateurPrixApp(),
      ),
    );

    await tester.tap(find.text('Explorer les produits'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'riz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Riz parfumé'), findsOneWidget);
    expect(find.text('1250.00 XAF'), findsOneWidget);
  });

  testWidgets('product screen renders product details and comparison offers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
          ],
          child: const ProductScreen(productId: '15'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Riz parfumé'), findsOneWidget);
    expect(find.text('Comparaison d’offres'), findsOneWidget);
    expect(find.text('Supermarché local'), findsOneWidget);
    expect(find.text('1250.00 XAF'), findsAtLeastNWidgets(1));
  });
}

class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository() : super(Dio());

  @override
  Future<CatalogProductPage> searchProducts(
    dynamic request, {
    CancelToken? cancelToken,
  }) async {
    final query = request is CatalogSearchRequest ? request.query : request as String;
    expect(query, 'riz');
    return const CatalogProductPage(
      count: 1,
      results: [
        CatalogProduct(
          id: 15,
          name: 'Riz parfumé',
          slug: 'riz-parfume',
          availability: 'unknown',
          isActive: true,
          isVerified: true,
          priceSnapshot: '1250.00',
          priceSnapshotCurrency: 'XAF',
        ),
      ],
    );
  }

  @override
  Future<CatalogProduct> getProduct(int productId, {CancelToken? cancelToken}) async {
    expect(productId, 15);
    return const CatalogProduct(
      id: 15,
      name: 'Riz parfumé',
      slug: 'riz-parfume',
      availability: 'available',
      isActive: true,
      isVerified: true,
      priceSnapshot: '1250.00',
      priceSnapshotCurrency: 'XAF',
      description: 'Riz parfumé pour les repas du quotidien.',
    );
  }

  @override
  Future<ComparisonOfferPage> getComparisonOffers(
    int productId, {
    int page = 1,
    int pageSize = 20,
    String? location,
    CancelToken? cancelToken,
  }) async {
    expect(productId, 15);
    return const ComparisonOfferPage(
      count: 1,
      results: [
        ComparisonOffer(
          id: 77,
          product: 15,
          productName: 'Riz parfumé',
          amount: '1250.00',
          currency: 'XAF',
          quantity: '1.0000',
          merchantName: 'Supermarché local',
          unitSymbol: 'kg',
          unitCode: 'kg',
          isActive: true,
          isPromotion: false,
          isCurrentlyValid: true,
          comparisonReasons: ['same_product'],
          availability: 'available',
          normalizedUnitPrice: '1250.000000',
          normalizedUnit: CatalogUnit(
            id: 1,
            code: 'kg',
            symbol: 'kg',
            unitType: 'mass',
          ),
        ),
      ],
    );
  }
}
