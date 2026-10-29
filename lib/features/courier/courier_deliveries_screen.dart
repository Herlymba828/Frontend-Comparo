import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import '../commerce/commerce_models.dart';
import 'courier_repository.dart';
import '../identity/data/auth_providers.dart';

/// Deliveries carried by the courier ([available] = false) or open in
/// their zones ([available] = true).
class CourierDeliveriesScreen extends ConsumerWidget {
  const CourierDeliveriesScreen({super.key, required this.available});

  final bool available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(courierDeliveriesProvider(available));
    // "Mes courses" lists only the deliveries this courier carries (not the
    // ones of their own orders or shop).
    final courierId = ref.watch(authSessionProvider).value?.id;
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(courierDeliveriesProvider(available)),
      child: AsyncBody<List<Delivery>>(
        value: deliveries,
        onRetry: () => ref.invalidate(courierDeliveriesProvider(available)),
        builder: (items) {
          final shown = available
              ? items
              : items.where((d) => d.courierId == courierId).toList();
          if (shown.isEmpty) {
            return EmptyState(
              icon: Icons.delivery_dining,
              title: available
                  ? 'Aucune livraison ouverte dans vos zones.'
                  : 'Aucune course pour le moment.',
              message: available
                  ? 'Vérifiez que vous êtes disponible dans l’onglet Profil.'
                  : null,
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.space16),
            itemCount: shown.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.space8),
            itemBuilder: (context, index) {
              final delivery = shown[index];
              return MarketSurface(
                onTap: () => context.push('/courier/deliveries/${delivery.id}'),
                padding: const EdgeInsets.all(AppSpacing.space12),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.number,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(delivery.city.isEmpty ? '—' : delivery.city),
                        ],
                      ),
                    ),
                    StatusStamp(delivery.status),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
