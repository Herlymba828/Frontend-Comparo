import 'package:share_plus/share_plus.dart';

import '../../core/formatters/price_formatter.dart';
import '../catalog/models/catalog_product.dart';

/// Text shared with any app of the phone (Facebook, WhatsApp, messages...).
/// A product without a known price is shared without any amount.
String productShareText(CatalogProduct product) {
  final price = product.priceSnapshot;
  final hasPrice = price != null && price.trim().isNotEmpty;
  return hasPrice
      ? '${product.name} : meilleur prix connu '
            '${formatPrice(price, product.priceSnapshotCurrency)}, '
            'sur Comparateur Prix.'
      : '${product.name}, à comparer sur Comparateur Prix.';
}

Future<void> shareProduct(CatalogProduct product) async {
  await SharePlus.instance.share(ShareParams(text: productShareText(product)));
}
