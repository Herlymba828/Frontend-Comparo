/// Composants d'identité Comparo pour Flutter.
///
/// Les couleurs, dimensions et styles viennent de `src/tokens.dart`, généré
/// depuis `tokens.json` du design system : ne le modifiez pas à la main.
///
/// ```dart
/// MaterialApp(theme: ComparoTheme.light(), darkTheme: ComparoTheme.dark());
/// ```
library;

export 'src/common.dart' show ComparoContext, formatXaf, priceDeviationPercent, warningThreshold, shortVendorName, Skeleton;
export 'src/list_summary.dart';
export 'src/input_nav.dart';
export 'src/layout.dart';
export 'src/picto.dart';
export 'src/price.dart';
export 'src/price_line.dart' show PriceLine, PriceLineOffer, PriceLineSize, PriceLineLayout, PriceLineItem;
export 'src/proof_line.dart';
export 'src/slate.dart';
export 'src/tokens.dart';
