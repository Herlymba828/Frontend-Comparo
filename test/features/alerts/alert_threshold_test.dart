import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/alerts/create_price_alert_dialog.dart';

void main() {
  test('accepts amounts the API accepts', () {
    for (final value in [
      '1200',
      '1200.50',
      '1200,5',
      ' 0.01 ',
      '9999999999.99',
    ]) {
      expect(validateAlertThreshold(value), isNull, reason: value);
    }
  });

  test('refuses amounts the API would reject', () {
    for (final value in ['', 'abc', '0', '-5', '999.999', '12345678901']) {
      expect(validateAlertThreshold(value), isNotNull, reason: value);
    }
  });
}
