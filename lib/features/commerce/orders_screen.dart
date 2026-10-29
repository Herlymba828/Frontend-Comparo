import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import 'commerce_models.dart';
import 'commerce_repository.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: SignedInGate(
        builder: (user) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myOrdersProvider),
          child: AsyncBody<List<CustomerOrder>>(
            value: ref.watch(myOrdersProvider),
            onRetry: () => ref.invalidate(myOrdersProvider),
            builder: (orders) => orders.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune commande pour le moment.',
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.space16),
                    itemCount: orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.space8),
                    itemBuilder: (context, index) =>
                        OrderTile(order: orders[index], basePath: '/orders'),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Order summary card; also used in the merchant space.
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.basePath});

  final CustomerOrder order;
  final String basePath;

  @override
  Widget build(BuildContext context) {
    return MarketSurface(
      onTap: () => context.push('$basePath/${order.id}'),
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Row(
        children: [
          Icon(
            order.isPickup
                ? Icons.storefront_outlined
                : Icons.local_shipping_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.number,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  formatDateTime(order.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.space4),
                StatusStamp(order.status),
              ],
            ),
          ),
          Text(
            formatPrice(order.total, order.currency),
            style: AppTextStyles.priceSecondary,
          ),
        ],
      ),
    );
  }
}
