import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/product/product_helpers.dart';

void main() {
  group('readableSource', () {
    test('keeps a source a person can read', () {
      expect(readableSource('Supermarché local'), 'Supermarché local');
      expect(readableSource('  Espace marchand '), 'Espace marchand');
    });

    test('hides an internal identifier', () {
      expect(readableSource('frontend-demo:riz-1kg:grocery'), isNull);
      expect(readableSource('import_v2:ab12'), isNull);
    });

    test('treats an empty or missing source as none', () {
      expect(readableSource(null), isNull);
      expect(readableSource('   '), isNull);
    });
  });
}
