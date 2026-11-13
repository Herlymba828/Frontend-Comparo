import 'package:flutter/material.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../catalog/models/catalog_product.dart';

/// Mini-corde of a result: the current prices of a product placed on a line
/// by unit price, the best offer highlighted, with the price range below.
/// Shown only when at least two prices compare.
class PriceRope extends StatelessWidget {
  const PriceRope({super.key, required this.prices, required this.offerCount});

  final List<CurrentPrice> prices;
  final int offerCount;

  static const _dot = 10.0;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final point in prices) double.tryParse(point.unitPrice),
    ].whereType<double>().toList();
    if (values.length < 2) {
      return const SizedBox.shrink();
    }
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final first = prices.first;
    final last = prices.last;
    final count = offerCount > prices.length ? offerCount : prices.length;
    final caption =
        '$count offres · de ${formatUnitPrice(first.unitPrice, first.currency)} '
        'à ${formatUnitPrice(last.unitPrice, last.currency)} / ${first.unit}';

    return Semantics(
      label: caption,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _dot + 4,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth - _dot;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(height: 2, color: AppColors.kraftEdge),
                    for (final point in prices)
                      if (double.tryParse(point.unitPrice) case final value?)
                        Positioned(
                          left: high == low
                              ? 0
                              : width * (value - low) / (high - low),
                          child: _Dot(best: point.isBestOffer),
                        ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.best});

  final bool best;

  @override
  Widget build(BuildContext context) => Container(
    width: PriceRope._dot,
    height: PriceRope._dot,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: best ? AppColors.accent : AppColors.surface,
      border: Border.all(
        color: best ? AppColors.primary : AppColors.ink,
        width: 1.5,
      ),
    ),
  );
}
