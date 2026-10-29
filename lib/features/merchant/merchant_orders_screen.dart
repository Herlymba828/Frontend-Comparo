import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
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
        builder: (orders) => orders.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Aucune commande reçue pour le moment.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: orders.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) => OrderTile(
                  order: orders[index],
                  basePath: '/merchant/orders',
                ),
              ),
      ),
    );
  }
}
