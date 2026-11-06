import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/commerce/basket_optimisation_screen.dart';
import 'package:frontend/features/merchant/merchant_repository.dart';
import 'package:frontend/features/merchant/merchant_stats_screen.dart';

void main() {
  test('only a published price with its type and unit can be replaced', () {
    ShopPrice price(String status, {Object? unit = 4}) => ShopPrice.fromJson({
      'id': 1,
      'product': 2,
      'product_name': 'Riz',
      'amount': '1250.00',
      'quantity': '1',
      'unit_symbol': 'kg',
      'status': status,
      'price_type': {'id': 3},
      'unit': unit,
    });
    expect(price('published').canBeReplaced, isTrue);
    expect(price('review').canBeReplaced, isFalse);
    expect(price('published', unit: null).canBeReplaced, isFalse);
  });

  test('a split solution lists each merchant with its delivery fee', () {
    final result = BasketOptimisation.fromJson({
      'solutions': [
        {
          'kind': 'split',
          'products_total': '1500.00',
          'delivery_total': '0.00',
          'payment_fees': '0.00',
          'total': '1500.00',
          'merchants': [
            {
              'merchant_id': 7,
              'merchant_name': 'Boutique A',
              'products_total': '1000.00',
              'delivery_fee': '0.00',
              'lines': [
                {
                  'product_id': 1,
                  'product_name': 'Riz',
                  'offer_id': 9,
                  'packs': 2,
                  'pack': '1 kg',
                  'pack_price': '500.00',
                  'line_total': '1000.00',
                },
              ],
            },
          ],
        },
      ],
      'unavailable': ['Huile'],
      'without_offer': [],
    });
    final solution = result.solutions.single;
    expect(solution.isSplit, isTrue);
    expect(solution.merchants.single.lines.single.packs, 2);
    expect(result.unavailable, ['Huile']);
  });

  test('shop stats keep the cancellation rate and the best sellers', () {
    final stats = ShopStats.fromJson({
      'days': 30,
      'orders': 3,
      'sold_orders': 2,
      'cancellation_rate': 33.3,
      'revenue': '4000.00',
      'refunded': '0.00',
      'average_basket': '2000.00',
      'daily': [
        {'date': '2026-11-01', 'orders': 2, 'revenue': '4000.00'},
      ],
      'top_products': [
        {'product_name': 'Riz', 'quantity': '3', 'revenue': '3000.00'},
      ],
    });
    expect(stats.cancellationRate, 33.3);
    expect(stats.topProducts.single.name, 'Riz');
    expect(stats.daily.single.orders, 2);
  });
}
