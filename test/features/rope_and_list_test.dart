import 'package:comparo_ui/comparo_ui.dart' show PriceLineLayout;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/catalog/models/catalog_product.dart';
import 'package:frontend/features/commerce/basket_optimisation_screen.dart';
import 'package:frontend/features/comparison/comparo_adapters.dart';

Map<String, dynamic> _point(
  int id,
  String unitPrice, {
  bool best = false,
  String? amount,
}) => {
  'offer_id': id,
  'merchant_id': id,
  'merchant_name': 'Boutique $id',
  // The price of the pack: equal to the unit price unless the test says so.
  'amount': amount ?? unitPrice,
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

  test('the corde takes the API prices as the design expects them', () {
    final offers = priceLineOffers([
      CurrentPrice.fromJson(_point(1, '1000', best: true)),
      CurrentPrice.fromJson(_point(2, '1380.50')),
    ]);

    expect(offers.map((offer) => offer.price), [1000, 1380.5]);
    expect(offers.map((offer) => offer.vendor), ['Boutique 1', 'Boutique 2']);
    expect(offers.map((offer) => offer.id), [1, 2]);
  });

  test('the corde places the unit price, not the price of the pack', () {
    // A 500 g pack at 950 F costs 1900 F/kg; a 1 kg pack at 1500 F costs
    // 1500 F/kg. The smaller price on the shelf is the dearer one per kg.
    final offers = priceLineOffers([
      CurrentPrice.fromJson(_point(1, '1900', amount: '950')),
      CurrentPrice.fromJson(_point(2, '1500', amount: '1500', best: true)),
    ]);

    expect(offers.map((offer) => offer.price), [1900, 1500]);
  });

  test('the cheapest per kg is the one the corde highlights', () {
    final offers = priceLineOffers([
      CurrentPrice.fromJson(_point(1, '1900', amount: '950')),
      CurrentPrice.fromJson(_point(2, '1500', amount: '1500', best: true)),
    ]);

    final layout = PriceLineLayout(offers, false);

    expect(layout.items.where((item) => item.best), hasLength(1));
    expect(layout.items.singleWhere((item) => item.best).offer.id, 2);
    expect(layout.sorted.first.vendor, 'Boutique 2');
  });

  test('a price that is not a number is left off the corde', () {
    final offers = priceLineOffers([
      CurrentPrice.fromJson(_point(1, '1000')),
      CurrentPrice.fromJson(_point(2, 'n/a')),
    ]);

    expect(offers, hasLength(1));
  });

  test('an offer without a readable unit price is left off the corde', () {
    final offers = priceLineOffers([
      CurrentPrice.fromJson(_point(1, '1000')),
      CurrentPrice.fromJson(_point(2, 'n/a', amount: '1200')),
    ]);

    expect(offers.map((offer) => offer.id), [1]);
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
