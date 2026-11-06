import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';

/// One published price of the product's history (PJ-004).
class HistoryPoint {
  const HistoryPoint({
    required this.observedAt,
    required this.amount,
    required this.currency,
    required this.quantity,
    required this.unitCode,
    required this.unitPrice,
    required this.merchantName,
    required this.location,
  });

  final DateTime? observedAt;
  final String amount;
  final String currency;
  final String quantity;
  final String unitCode;

  /// Price per base unit, empty when the unit has no exact conversion.
  final String unitPrice;
  final String merchantName;
  final String location;

  factory HistoryPoint.fromJson(Map<String, dynamic> json) => HistoryPoint(
    observedAt: json.dateOrNull('observed_at'),
    amount: json.string('amount'),
    currency: json.string('currency', 'XAF'),
    quantity: json.string('quantity', '1'),
    // The symbol ("kg"), not the internal code.
    unitCode: json.string('unit_symbol', json.string('unit_code')),
    unitPrice: json.string('unit_price'),
    merchantName: json.string('merchant_name', 'Prix relevé'),
    location: json.string('location'),
  );
}

class PriceTrend {
  const PriceTrend({
    required this.direction,
    required this.changePct,
    required this.windowDays,
    required this.sampleCount,
    required this.limits,
  });

  final String direction;
  final String changePct;
  final int windowDays;
  final int sampleCount;
  final String limits;

  factory PriceTrend.fromJson(Map<String, dynamic> json) => PriceTrend(
    direction: json.string('direction', 'uncertain'),
    changePct: json.string('change_pct', '0'),
    windowDays: json.intOrNull('window_days') ?? 30,
    sampleCount: json.intOrNull('sample_count') ?? 0,
    limits: json.string('limits'),
  );
}

class ForecastPoint {
  const ForecastPoint({
    required this.date,
    required this.predicted,
    required this.lower,
    required this.upper,
    required this.confidence,
  });

  final DateTime? date;
  final String predicted;
  final String lower;
  final String upper;
  final double confidence;

  factory ForecastPoint.fromJson(Map<String, dynamic> json) => ForecastPoint(
    date: json.dateOrNull('date'),
    predicted: json.string('predicted'),
    lower: json.string('lower'),
    upper: json.string('upper'),
    confidence: double.tryParse(json.string('confidence', '0')) ?? 0,
  );
}

/// A forecast, or the reason there is none (never a misleading estimate).
class PriceForecast {
  const PriceForecast({
    required this.isAvailable,
    this.reason = '',
    this.priceUnit = '',
    this.historyDays,
    this.interval = '',
    this.limits = '',
    this.points = const [],
  });

  final bool isAvailable;
  final String reason;
  final String priceUnit;
  final int? historyDays;
  final String interval;
  final String limits;
  final List<ForecastPoint> points;

  factory PriceForecast.fromJson(Map<String, dynamic> json) => PriceForecast(
    isAvailable: json.flag('available'),
    reason: json.string('reason'),
    priceUnit: json.string('price_unit'),
    historyDays: json.intOrNull('history_days'),
    interval: json.string('interval'),
    limits: json.string('limits'),
    points: json.maps('points').map(ForecastPoint.fromJson).toList(),
  );
}

class PriceEvolution {
  const PriceEvolution({
    required this.history,
    required this.trend,
    required this.forecast,
  });

  final List<HistoryPoint> history;
  final PriceTrend? trend;
  final PriceForecast forecast;

  factory PriceEvolution.fromJson(Map<String, dynamic> json) {
    final trend = json.mapOrNull('trend');
    final forecast = json.mapOrNull('forecast');
    return PriceEvolution(
      history: json.maps('history').map(HistoryPoint.fromJson).toList(),
      trend: trend == null ? null : PriceTrend.fromJson(trend),
      forecast: forecast == null
          ? const PriceForecast(isAvailable: false)
          : PriceForecast.fromJson(forecast),
    );
  }
}

const trendLabels = {
  'up': 'En hausse',
  'down': 'En baisse',
  'stable': 'Stable',
  'uncertain': 'Incertaine',
};

final priceEvolutionProvider = FutureProvider.autoDispose
    .family<PriceEvolution, int>(
      (ref, productId) => ref
          .watch(jsonApiProvider)
          .getOne(
            'api/analytics/products/$productId/evolution/',
            PriceEvolution.fromJson,
          ),
    );

/// History, trend and forecast of a product, each with its limits.
class PriceEvolutionSection extends ConsumerWidget {
  const PriceEvolutionSection({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evolution = ref.watch(priceEvolutionProvider(productId));
    return evolution.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => SectionCard(
        title: 'Évolution du prix',
        children: [Text(errorText(error))],
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HistoryCard(points: data.history),
          const SizedBox(height: AppSpacing.space12),
          _TrendCard(trend: data.trend),
          const SizedBox(height: AppSpacing.space12),
          _ForecastCard(forecast: data.forecast),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({required this.points});

  final List<HistoryPoint> points;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _all = false;

  static const _shown = 5;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) {
      return const SectionCard(
        title: 'Historique des prix',
        children: [Text('Aucun prix publié ces 90 derniers jours.')],
      );
    }
    final charted = points.where((p) => p.unitPrice.isNotEmpty).toList();
    final listed = _all ? points : points.take(_shown).toList();
    return SectionCard(
      title: 'Historique des prix',
      children: [
        if (charted.length >= 2) ...[
          Text(
            'Prix par unité, 90 derniers jours',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.space8),
          SizedBox(height: 120, child: PriceHistoryChart(points: charted)),
          const SizedBox(height: AppSpacing.space8),
        ],
        for (final point in listed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${formatPrice(point.amount, point.currency)} · '
                      '${formatQuantity(point.quantity)} ${point.unitCode}'
                  .trim(),
            ),
            subtitle: Text(
              [
                formatDateTime(point.observedAt),
                point.merchantName,
                if (point.location.isNotEmpty) point.location,
              ].join(' · '),
            ),
          ),
        if (points.length > _shown)
          TextButton(
            onPressed: () => setState(() => _all = !_all),
            child: Text(_all ? 'Voir moins' : 'Voir les ${points.length} prix'),
          ),
      ],
    );
  }
}

/// Price per unit over time; the oldest point on the left.
class PriceHistoryChart extends StatelessWidget {
  const PriceHistoryChart({super.key, required this.points});

  final List<HistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final point in points.reversed)
        if (point.observedAt != null &&
            double.tryParse(point.unitPrice) != null)
          (point.observedAt!, double.parse(point.unitPrice)),
    ];
    final low = values.map((v) => v.$2).reduce((a, b) => a < b ? a : b);
    final high = values.map((v) => v.$2).reduce((a, b) => a > b ? a : b);
    return Semantics(
      label:
          'Graphique : prix entre ${low.round()} et ${high.round()} '
          'sur ${values.length} relevés',
      child: CustomPaint(
        painter: _HistoryPainter(
          values: values,
          color: Theme.of(context).colorScheme.primary,
          grid: Theme.of(context).dividerColor,
        ),
        child: Align(
          alignment: Alignment.topRight,
          child: Text(
            '${high.round()} · ${low.round()}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.values,
    required this.color,
    required this.grid,
  });

  final List<(DateTime, double)> values;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }
    final first = values.first.$1.millisecondsSinceEpoch.toDouble();
    final span = (values.last.$1.millisecondsSinceEpoch - first)
        .toDouble()
        .clamp(1, double.infinity);
    final low = values.map((v) => v.$2).reduce((a, b) => a < b ? a : b);
    final high = values.map((v) => v.$2).reduce((a, b) => a > b ? a : b);
    final range = (high - low) == 0 ? 1 : high - low;
    Offset at((DateTime, double) value) => Offset(
      (value.$1.millisecondsSinceEpoch - first) / span * size.width,
      size.height - 8 - (value.$2 - low) / range * (size.height - 24),
    );
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()..color = grid,
    );
    final line = Path()..moveTo(at(values.first).dx, at(values.first).dy);
    for (final value in values.skip(1)) {
      line.lineTo(at(value).dx, at(value).dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final value in values) {
      canvas.drawCircle(at(value), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_HistoryPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final PriceTrend? trend;

  @override
  Widget build(BuildContext context) {
    final trend = this.trend;
    if (trend == null) {
      return const SectionCard(
        title: 'Tendance',
        children: [Text('Pas encore assez de prix pour dégager une tendance.')],
      );
    }
    final change = double.tryParse(trend.changePct) ?? 0;
    return SectionCard(
      title: 'Tendance',
      trailing: Text(
        trendLabels[trend.direction] ?? trend.direction,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      children: [
        Text(
          '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} % sur '
          '${trend.windowDays} jours (${trend.sampleCount} prix).',
        ),
        const SizedBox(height: AppSpacing.space4),
        Text(trend.limits, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final PriceForecast forecast;

  @override
  Widget build(BuildContext context) {
    final points = forecast.points;
    if (!forecast.isAvailable || points.isEmpty) {
      return SectionCard(
        title: 'Prévision',
        children: [
          Text(
            forecast.reason.isEmpty
                ? 'Aucune prévision disponible.'
                : forecast.reason,
          ),
        ],
      );
    }
    final last = points.last;
    final unit = forecast.priceUnit.isEmpty ? '' : ' / ${forecast.priceUnit}';
    return SectionCard(
      title: 'Prévision',
      children: [
        Text(
          'Vers le ${formatDateTime(last.date).split(' ').first} : '
          '${formatPrice(last.predicted, 'XAF')}$unit',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          'Entre ${formatPrice(last.lower, 'XAF')} et '
          '${formatPrice(last.upper, 'XAF')} '
          '(intervalle ${forecast.interval}), confiance '
          '${(last.confidence * 100).round()} %.',
        ),
        if (forecast.historyDays != null)
          Text(
            'Calculée sur ${forecast.historyDays} jours de prix.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.space4),
        Text(forecast.limits, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
