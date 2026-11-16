import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/formatters/price_formatter.dart';

void main() {
  test(
    'formats XAF with French grouping without rounding the source value',
    () {
      expect(
        formatPrice('1234567890.123456', 'XAF'),
        '1\u00a0234\u00a0567\u00a0890,123456 FCFA',
      );
    },
  );

  test('keeps a known amount visible when its currency is missing', () {
    expect(
      formatPrice('1250.00', null),
      '1\u00a0250,00 — devise non renseignée',
    );
  });

  test('writes the CFA franc as FCFA, without decimals that are zero', () {
    expect(formatPrice('1650.00', 'XAF'), '1\u00a0650 FCFA');
    expect(formatPrice('950', 'XAF'), '950 FCFA');
    // A real decimal is never dropped nor rounded.
    expect(formatPrice('1234.50', 'XAF'), '1\u00a0234,50 FCFA');
  });

  test('other currencies keep their cents and their code', () {
    expect(formatPrice('10.00', 'EUR'), '10,00 EUR');
  });

  test('does not render a currency when the amount is missing', () {
    expect(formatPrice(null, 'XAF'), 'Prix non renseigné');
  });

  test('rounds derived unit prices half up, by currency', () {
    expect(formatUnitPrice('1900.000000', 'XAF'), '1 900 FCFA');
    expect(formatUnitPrice('1379.500000', 'XAF'), '1 380 FCFA');
    expect(formatUnitPrice('9.995000', 'EUR'), '10,00 EUR');
    expect(formatUnitPrice('0.004', 'EUR'), '0,00 EUR');
  });

  test('formats quantities without trailing zeros', () {
    expect(formatQuantity('500.0000'), '500');
    expect(formatQuantity('1.5000'), '1,5');
    expect(formatQuantity('0.2500'), '0,25');
  });
}
