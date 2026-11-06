import 'package:frontend/features/product/price_evolution.dart';

/// Product screens in widget tests: no network call for the price evolution.
final noPriceEvolution = priceEvolutionProvider.overrideWith(
  (ref, productId) async => const PriceEvolution(
    history: [],
    trend: null,
    forecast: PriceForecast(isAvailable: false),
  ),
);
