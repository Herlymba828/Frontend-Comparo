import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/features/contributions/price_input.dart';
import 'package:frontend/features/contributions/price_report_repository.dart';

void main() {
  group('parseObservedPrice in XAF', () {
    test('accepts whole amounts with or without thousands separators', () {
      for (final (typed, value) in [
        ('1500', '1500'),
        ('1 500', '1500'),
        ('1 500', '1500'),
        ('1 500', '1500'),
        ('1.500.000', '1500000'),
        (' 950 ', '950'),
        ('0750', '750'),
      ]) {
        final parsed = parseObservedPrice(typed);
        expect(parsed.value, value, reason: typed);
        expect(parsed.isValid, isTrue);
      }
    });

    test('refuses cents, words, zero and absurd amounts', () {
      expect(
        parseObservedPrice('1500,50').error,
        'Le prix en XAF s’écrit sans centimes.',
      );
      expect(parseObservedPrice('15.5').error, contains('sans centimes'));
      expect(parseObservedPrice('').error, 'Indiquez le prix affiché.');
      expect(parseObservedPrice('abc').error, contains('Saisissez un nombre'));
      expect(parseObservedPrice('1 50').error, contains('Saisissez un nombre'));
      expect(parseObservedPrice('0').error, 'Le prix doit être positif.');
      expect(parseObservedPrice('20 000 000').error, contains('trop élevé'));
    });
  });

  test('currencies with cents accept a comma or a dot', () {
    expect(parseObservedPrice('2,50', currency: 'EUR').value, '2.50');
    expect(parseObservedPrice('2.5', currency: 'eur').value, '2.5');
    expect(parseObservedPrice('2,505', currency: 'EUR').isValid, isFalse);
  });

  test('parseQuantity accepts positive decimals only', () {
    expect(parseQuantity('1'), '1');
    expect(parseQuantity('0,5'), '0.5');
    expect(parseQuantity('0'), isNull);
    expect(parseQuantity('-1'), isNull);
    expect(parseQuantity('kg'), isNull);
  });

  group('API answers', () {
    test('stores and price checks are read from JSON', () {
      final store = ReportStore.fromJson({
        'id': 4,
        'name': 'Étal central',
        'merchant_id': 1,
        'merchant_name': 'Marché Mont-Bouët',
        'street': 'Avenue Bouët',
        'city': 'Libreville',
        'distance_m': 120,
      });
      expect(store.distanceM, 120);
      expect(store.address, 'Avenue Bouët, Libreville');

      final check = PriceCheck.fromJson({
        'sample_size': 4,
        'median_unit_price': '1025.00',
        'base_unit': 'kg',
        'unit_price': '9000.00',
        'is_outlier': true,
        'typical_quantity': '1',
        'typical_unit': 'kg',
      });
      expect(check.isOutlier, isTrue);
      expect(check.medianUnitPrice, '1025.00');
      expect(check.typicalUnit, 'kg');
    });

    test('a 409 duplicate becomes a DuplicateReportException', () {
      final error = translateReportError(
        const ApiException(
          kind: ApiErrorKind.http,
          statusCode: 409,
          code: 'duplicate_report',
          detail: 'Déjà relevé.',
          fields: {'existing_contribution': 12, 'existing_is_mine': false},
        ),
      );
      expect(error, isA<DuplicateReportException>());
      error as DuplicateReportException;
      expect(error.existingId, 12);
      expect(error.isMine, isFalse);
      expect(error.message, 'Déjà relevé.');
    });

    test('an unconfirmed unusual price becomes an UnusualPriceException', () {
      final error = translateReportError(
        const ApiException(
          kind: ApiErrorKind.http,
          statusCode: 400,
          fields: {
            'observed_price': ['Ce prix est très éloigné.'],
            'price_check': {'sample_size': 4, 'is_outlier': true},
          },
        ),
      );
      expect(error, isA<UnusualPriceException>());
      expect((error as UnusualPriceException).check.isOutlier, isTrue);
    });

    test('other errors are left unchanged', () {
      const original = ApiException(kind: ApiErrorKind.http, statusCode: 400);
      expect(translateReportError(original), same(original));
    });
  });
}
