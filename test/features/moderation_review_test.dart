import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/space_scaffold.dart';
import 'package:frontend/features/moderation/moderation_review_screens.dart';
import 'package:frontend/features/moderation/moderation_screen.dart';

void main() {
  test('only an open or reviewed anomaly waits for a decision', () {
    PriceAnomaly anomaly(String status) => PriceAnomaly.fromJson({
      'id': 1,
      'product_name': 'Riz',
      'merchant_name': 'Boutique',
      'anomaly_type': 'price_spike',
      'severity': 'high',
      'status': status,
      'expected_range_min': '500.00',
      'expected_range_max': '2000.00',
      'deviation_ratio': '3.5000',
      'notes': '',
      'detected_at': '2026-11-05T08:00:00Z',
    });
    expect(anomaly('open').isOpen, isTrue);
    expect(anomaly('under_review').isOpen, isTrue);
    expect(anomaly('dismissed').isOpen, isFalse);
  });

  test('the moderation space has its four tabs', () {
    expect(spaceTabIndex(moderationTabs, '/moderation/anomalies'), 2);
    expect(spaceTabIndex(moderationTabs, '/moderation/shops'), 3);
  });
}
