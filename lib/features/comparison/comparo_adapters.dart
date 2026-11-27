import 'package:comparo_ui/comparo_ui.dart';

import '../catalog/models/catalog_product.dart';

/// The corde of a product, from the API's current prices
/// (`apps/pricing/summary.py`: the 8 cheapest of the comparable group, the
/// number `PriceLine.maxOffers` allows). A price the app cannot read as a
/// number is left off rather than guessed.
///
/// The corde places the **unit price** (per kg, per litre…), the value the
/// server ranks by: only unit prices of one group compare. The price of the
/// pack would put a small pack first and highlight the dearer offer per kg.
List<PriceLineOffer> priceLineOffers(List<CurrentPrice> prices) => [
  for (final price in prices)
    if (num.tryParse(price.unitPrice) case final unitPrice?)
      PriceLineOffer(
        price: unitPrice,
        vendor: price.merchantName,
        id: price.offerId,
      ),
];
