import 'package:comparo_ui/comparo_ui.dart';

import '../catalog/models/catalog_product.dart';

/// The corde of a product, from the API's current prices
/// (`apps/pricing/summary.py`: the 8 cheapest of the comparable group, the
/// number `PriceLine.maxOffers` allows). A price the app cannot read as a
/// number is left off rather than guessed.
List<PriceLineOffer> priceLineOffers(List<CurrentPrice> prices) => [
  for (final price in prices)
    if (num.tryParse(price.amount) case final amount?)
      PriceLineOffer(
        price: amount,
        vendor: price.merchantName,
        id: price.offerId,
      ),
];
