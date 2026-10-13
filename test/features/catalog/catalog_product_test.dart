import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/catalog/models/catalog_product.dart';
import 'package:frontend/features/catalog/models/catalog_product_page.dart';

void main() {
  test('parses catalog products and preserves decimal precision', () {
    final page = CatalogProductPage.fromJson({
      'count': 1,
      'next': null,
      'previous': null,
      'results': [
        {
          'id': 42,
          'name': 'Café moulu',
          'slug': 'cafe-moulu',
          'sku': null,
          'barcode': null,
          'category': {'id': 3, 'name': 'Épicerie', 'slug': 'epicerie'},
          'brand': null,
          'default_unit': null,
          'image_url': '',
          'price_snapshot': '1250.10',
          'price_snapshot_currency': 'XAF',
          'price_snapshot_updated_at': null,
          'availability': 'unknown',
          'is_active': true,
          'is_verified': false,
        },
      ],
    });

    final product = page.results.single;
    expect(page.count, 1);
    expect(product.id, 42);
    expect(product.category?.name, 'Épicerie');
    expect(product.brand, isNull);
    expect(product.availability, 'unknown');
    expect(product.priceSnapshot, '1250.10');
    expect(product.priceSnapshotCurrency, 'XAF');
  });

  test('rejects malformed required product fields', () {
    expect(
      () => CatalogProduct.fromJson({'name': 'Produit'}),
      throwsA(isA<TypeError>()),
    );
  });
}
