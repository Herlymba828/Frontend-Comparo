import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/catalog/models/catalog_product.dart';
import 'package:frontend/features/commerce/basket_optimisation_screen.dart';
import 'package:frontend/features/comparison/price_rope.dart';

Map<String, dynamic> _point(int id, String unitPrice, {bool best = false}) => {
  'offer_id': id,
  'merchant_id': id,
  'merchant_name': 'Boutique $id',
  'amount': unitPrice,
  'currency': 'XAF',
  'unit_price': unitPrice,
  'unit': 'kg',
  'is_best_offer': best,
};

void main() {
  test('a result reads its offer count and current prices', () {
    final product = CatalogProduct.fromJson({
      'id': 15,
      'name': 'Riz',
      'slug': 'riz',
      'availability': 'available',
      'is_active': true,
      'is_verified': true,
      'offer_count': 4,
      'current_prices': [
        _point(1, '1000.000000', best: true),
        _point(2, '1380.000000'),
      ],
    });

    expect(product.offerCount, 4);
    expect(product.currentPrices.map((point) => point.offerId), [1, 2]);
    expect(product.currentPrices.first.isBestOffer, isTrue);
  });

  test('a product detail without summary still reads', () {
    final product = CatalogProduct.fromJson({
      'id': 15,
      'name': 'Riz',
      'slug': 'riz',
      'availability': 'available',
      'is_active': true,
      'is_verified': true,
    });

    expect(product.offerCount, 0);
    expect(product.currentPrices, isEmpty);
  });

  Future<void> pumpRope(WidgetTester tester, List<CurrentPrice> prices) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: PriceRope(prices: prices, offerCount: 3),
            ),
          ),
        ),
      );

  testWidgets('the rope shows the range of unit prices', (tester) async {
    await pumpRope(tester, [
      CurrentPrice.fromJson(_point(1, '1000', best: true)),
      CurrentPrice.fromJson(_point(2, '1380')),
    ]);

    expect(find.textContaining('3 offres · de 1'), findsOneWidget);
    expect(find.textContaining('/ kg'), findsOneWidget);
  });

  testWidgets('no rope with a single price', (tester) async {
    await pumpRope(tester, [CurrentPrice.fromJson(_point(1, '1000'))]);

    expect(find.textContaining('offres'), findsNothing);
  });

  test('"Ma liste" reads each store and the saving', () {
    final result = BasketOptimisation.fromJson({
      'delivery_mode': 'pickup',
      'solutions': [
        {
          'kind': 'split',
          'merchants': <Map<String, dynamic>>[],
          'products_total': '1500.00',
          'delivery_total': '0.00',
          'payment_fees': '0.00',
          'total': '1500.00',
          'savings': '250.00',
        },
      ],
      'stores': [
        {
          'merchant_id': 1,
          'merchant_name': 'Principale',
          'products_total': '1750.00',
          'delivery_fee': '0.00',
          'total': '1750.00',
          'found_count': 2,
          'missing': <String>[],
          'is_complete': true,
        },
        {
          'merchant_id': 2,
          'merchant_name': 'Autre',
          'products_total': '1000.00',
          'delivery_fee': '0.00',
          'total': '1000.00',
          'found_count': 1,
          'missing': ['Huile'],
          'is_complete': false,
        },
      ],
      'most_expensive_total': '1750.00',
      'unavailable': <String>[],
      'without_offer': <String>[],
    });

    expect(result.solutions.single.savings, '250.00');
    expect(result.stores.map((store) => store.isComplete), [true, false]);
    expect(result.stores.last.missing, ['Huile']);
    expect(result.mostExpensiveTotal, '1750.00');
  });

  test('an older optimisation answer still reads', () {
    final result = BasketOptimisation.fromJson({
      'solutions': <Map<String, dynamic>>[],
      'unavailable': <String>[],
      'without_offer': <String>[],
    });

    expect(result.stores, isEmpty);
    expect(result.mostExpensiveTotal, isNull);
  });
}
