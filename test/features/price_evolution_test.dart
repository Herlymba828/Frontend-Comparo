import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/budget/budget_repository.dart';
import 'package:frontend/features/product/price_evolution.dart';

void main() {
  group('PriceEvolution', () {
    test('a missing forecast keeps its reason and no points', () {
      final evolution = PriceEvolution.fromJson({
        'history': [
          {
            'observed_at': '2026-11-01T10:00:00Z',
            'amount': '1200.00',
            'currency': 'XAF',
            'quantity': '1',
            'unit_code': 'kg',
            'unit_price': '1200.00',
            'merchant_name': 'Boutique',
            'location': 'Libreville',
          },
        ],
        'trend': null,
        'forecast': {'available': false, 'reason': 'Pas assez de relevés.'},
      });
      expect(evolution.history.single.merchantName, 'Boutique');
      expect(evolution.trend, isNull);
      expect(evolution.forecast.isAvailable, isFalse);
      expect(evolution.forecast.reason, 'Pas assez de relevés.');
      expect(evolution.forecast.points, isEmpty);
    });

    test('a forecast keeps its interval and confidence', () {
      final forecast = PriceForecast.fromJson({
        'available': true,
        'price_unit': 'kg',
        'interval': '80%',
        'history_days': 12,
        'points': [
          {
            'date': '2026-11-20',
            'predicted': '1100.00',
            'lower': '1000.00',
            'upper': '1200.00',
            'confidence': '0.6000',
          },
        ],
      });
      expect(forecast.points.single.lower, '1000.00');
      expect(forecast.points.single.confidence, closeTo(0.6, 1e-9));
    });
  });

  test('a budget without a value keeps the total empty', () {
    final budget = Budget.fromJson({
      'id': 1,
      'name': 'Courses',
      'planned_for': null,
      'estimate': {
        'items': [
          {
            'product': 3,
            'product_name': 'Riz',
            'quantity': '2',
            'unit': 'kg',
            'current_total': '2400.00',
            'recent_average_total': null,
            'recent_samples': 0,
            'forecast': null,
          },
        ],
        'current_total': '2400.00',
        'recent_average_total': null,
        'forecast_total': null,
        'limits': 'Estimation indicative.',
      },
    });
    expect(budget.currentTotal, '2400.00');
    expect(budget.forecastTotal, isEmpty);
    expect(budget.lines.single.forecast, isNull);
  });
}
