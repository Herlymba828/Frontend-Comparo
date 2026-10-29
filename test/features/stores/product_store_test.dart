import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/stores/stores_repository.dart';

void main() {
  test('reads a store row of the stores API', () {
    final store = ProductStore.fromJson({
      'offer_id': 1,
      'product_id': 3,
      'product_name': 'Riz',
      'merchant_id': 1,
      'merchant_name': 'Marché démo',
      'location_id': 2,
      'location_name': 'Boutique — Centre-ville',
      'street': 'Centre-ville',
      'city': 'Libreville',
      'phone': '',
      'latitude': '0.390000',
      'longitude': '9.454000',
      'distance_km': 0.22,
      'amount': '950.00',
      'currency': 'XAF',
      'quantity': '500.0000',
      'unit_symbol': 'g',
      'unit_price': '1900.00',
      'unit_price_unit': 'kg',
      'availability': 'available',
      'freshness': 'recent',
      'verification_level': 'manual',
      'is_promotion': false,
    });
    expect(store.hasCoordinates, isTrue);
    expect(store.latitude, closeTo(0.39, 1e-9));
    expect(store.distanceKm, 0.22);
    expect(store.address, 'Centre-ville, Libreville');
  });

  test('a store without coordinates has no distance', () {
    final store = ProductStore.fromJson({
      'offer_id': 1,
      'latitude': null,
      'longitude': null,
      'distance_km': null,
    });
    expect(store.hasCoordinates, isFalse);
    expect(store.distanceKm, isNull);
  });
}
