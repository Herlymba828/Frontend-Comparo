import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import '../commerce/commerce_models.dart';
import '../commerce/orders_screen.dart';
import 'merchant_repository.dart';

/// Orders received by the shop.
class MerchantOrdersScreen extends ConsumerWidget {
  const MerchantOrdersScreen({super.key, required this.shopId});

  final int shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(shopOrdersProvider(shopId)),
      child: AsyncBody<List<CustomerOrder>>(
        value: ref.watch(shopOrdersProvider(shopId)),
        onRetry: () => ref.invalidate(shopOrdersProvider(shopId)),
        builder: (orders) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            MarketSurface(
              onTap: () => context.push('/merchant/stats'),
              padding: const EdgeInsets.all(AppSpacing.space12),
              child: const Row(
                children: [
                  Icon(Icons.insights_outlined, color: AppColors.primary),
                  SizedBox(width: AppSpacing.space12),
                  Expanded(child: Text('Statistiques de la boutique')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            if (orders.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Aucune commande reçue pour le moment.',
              ),
            for (final order in orders) ...[
              OrderTile(order: order, basePath: '/merchant/orders'),
              const SizedBox(height: AppSpacing.space8),
            ],
          ],
        ),
      ),
    );
  }
}
