import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';

class ShopStats {
  const ShopStats({
    required this.days,
    required this.orders,
    required this.soldOrders,
    required this.cancellationRate,
    required this.revenue,
    required this.refunded,
    required this.averageBasket,
    required this.daily,
    required this.topProducts,
  });

  final int days;
  final int orders;
  final int soldOrders;
  final double cancellationRate;
  final String revenue;
  final String refunded;
  final String averageBasket;
  final List<({DateTime? date, int orders, String revenue})> daily;
  final List<({String name, String quantity, String revenue})> topProducts;

  factory ShopStats.fromJson(Map<String, dynamic> json) => ShopStats(
    days: json.intOrNull('days') ?? 30,
    orders: json.intOrNull('orders') ?? 0,
    soldOrders: json.intOrNull('sold_orders') ?? 0,
    cancellationRate: (json['cancellation_rate'] as num?)?.toDouble() ?? 0,
    revenue: json.string('revenue', '0'),
    refunded: json.string('refunded', '0'),
    averageBasket: json.string('average_basket', '0'),
    daily: [
      for (final row in json.maps('daily'))
        (
          date: row.dateOrNull('date'),
          orders: row.intOrNull('orders') ?? 0,
          revenue: row.string('revenue', '0'),
        ),
    ],
    topProducts: [
      for (final row in json.maps('top_products'))
        (
          name: row.string('product_name'),
          quantity: row.string('quantity', '0'),
          revenue: row.string('revenue', '0'),
        ),
    ],
  );
}

const statsPeriods = [7, 30, 90];

final shopStatsProvider = FutureProvider.autoDispose.family<ShopStats, int>(
  (ref, days) => ref
      .watch(jsonApiProvider)
      .getOne(
        'api/merchants/me/stats/',
        ShopStats.fromJson,
        query: {'days': days},
      ),
);

/// The shop's activity over a period (PJ-030): sales, basket, best sellers.
class MerchantStatsScreen extends ConsumerStatefulWidget {
  const MerchantStatsScreen({super.key});

  @override
  ConsumerState<MerchantStatsScreen> createState() =>
      _MerchantStatsScreenState();
}

class _MerchantStatsScreenState extends ConsumerState<MerchantStatsScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final provider = shopStatsProvider(_days);
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: SignedInGate(
        role: 'merchant',
        builder: (user) => ListView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            SegmentedButton<int>(
              segments: [
                for (final days in statsPeriods)
                  ButtonSegment(value: days, label: Text('$days jours')),
              ],
              selected: {_days},
              onSelectionChanged: (value) =>
                  setState(() => _days = value.first),
            ),
            const SizedBox(height: AppSpacing.space12),
            AsyncBody<ShopStats>(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              builder: (stats) => _StatsBody(stats: stats),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final ShopStats stats;

  @override
  Widget build(BuildContext context) {
    final best = stats.daily.isEmpty
        ? 0.0
        : stats.daily
              .map((d) => double.tryParse(d.revenue) ?? 0)
              .reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Ventes',
          children: [
            InfoRow(
              'Chiffre d’affaires encaissé',
              formatPrice(stats.revenue, 'XAF'),
            ),
            InfoRow('Remboursé', formatPrice(stats.refunded, 'XAF')),
            InfoRow(
              'Commandes vendues',
              '${stats.soldOrders} sur ${stats.orders}',
            ),
            InfoRow('Panier moyen', formatPrice(stats.averageBasket, 'XAF')),
            InfoRow(
              'Taux d’annulation',
              '${stats.cancellationRate.toStringAsFixed(1)} %',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        SectionCard(
          title: 'Par jour',
          children: [
            if (stats.daily.isEmpty)
              const Text('Aucune vente sur la période.')
            else
              for (final day in stats.daily)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space4,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(formatDateTime(day.date).substring(0, 5)),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: best == 0
                              ? 0
                              : (double.tryParse(day.revenue) ?? 0) / best,
                          minHeight: 8,
                          semanticsLabel:
                              '${formatPrice(day.revenue, 'XAF')}, '
                              '${day.orders} commande(s)',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      Text(formatPrice(day.revenue, 'XAF')),
                    ],
                  ),
                ),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        SectionCard(
          title: 'Produits les plus vendus',
          children: [
            if (stats.topProducts.isEmpty)
              const Text('Aucune vente sur la période.')
            else
              for (final product in stats.topProducts)
                InfoRow(
                  product.name,
                  '${formatQuantity(product.quantity)} · '
                  '${formatPrice(product.revenue, 'XAF')}',
                ),
          ],
        ),
      ],
    );
  }
}
