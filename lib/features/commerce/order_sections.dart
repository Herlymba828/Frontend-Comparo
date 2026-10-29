import 'package:flutter/material.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import 'commerce_models.dart';

/// Order sections shared by the customer's and the merchant's views; each
/// view adds its own actions through [actions].

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key, required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final address = order.address;
    return SectionCard(
      title: order.number,
      trailing: StatusStamp(order.status),
      children: [
        InfoRow('Passée le', formatDateTime(order.createdAt)),
        InfoRow(
          'Réception',
          order.isPickup ? 'Retrait en boutique' : 'Livraison',
        ),
        if (address != null && !order.isPickup)
          InfoRow(
            'Adresse',
            [
              address['recipient_name'],
              address['street'],
              address['city'],
            ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
          ),
        if (order.cancelledReason.isNotEmpty)
          InfoRow('Motif', order.cancelledReason),
        const Divider(),
        for (final line in order.lines)
          InfoRow(
            '${double.tryParse(line.quantity)?.round() ?? line.quantity} ×',
            '${line.productName} — ${formatPrice(line.lineTotal, line.currency)}',
          ),
        const Divider(),
        if (order.deliveryCost != null)
          InfoRow('Livraison', formatPrice(order.deliveryCost, order.currency)),
        Row(
          children: [
            const Expanded(child: Text('Total')),
            PriceTag(
              label: formatPrice(order.total, order.currency),
              style: AppTextStyles.pricePrimary,
            ),
          ],
        ),
      ],
    );
  }
}

class PaymentCard extends StatelessWidget {
  const PaymentCard({
    super.key,
    required this.payment,
    this.children = const [],
    this.actions = const [],
  });

  final Payment payment;

  /// Explanations specific to the viewer, under the payment details.
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Paiement',
      trailing: StatusStamp(payment.status),
      children: [
        InfoRow('Référence', payment.number),
        InfoRow(
          'Moyen',
          '${paymentMethodLabels[payment.method] ?? payment.method} · '
              '${paymentProviderLabels[payment.provider] ?? payment.provider}',
        ),
        InfoRow(
          'Tentatives',
          '${payment.attemptCount} / ${payment.maxAttempts}',
        ),
        if (payment.amountRefunded != '0' && payment.amountRefunded != '0.00')
          InfoRow(
            'Remboursé',
            formatPrice(payment.amountRefunded, payment.currency),
          ),
        if (payment.failureReason.isNotEmpty)
          InfoRow('Motif', payment.failureReason),
        ...children,
        if (actions.isNotEmpty)
          Wrap(spacing: AppSpacing.space8, children: actions),
      ],
    );
  }
}

class PickupCard extends StatelessWidget {
  const PickupCard({super.key, required this.pickup, this.children = const []});

  final Pickup? pickup;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pickup = this.pickup;
    if (pickup == null) {
      return const SectionCard(
        title: 'Retrait en boutique',
        children: [Text('Le retrait sera préparé une fois la commande payée.')],
      );
    }
    return SectionCard(
      title: 'Retrait en boutique',
      trailing: StatusStamp(pickup.status),
      children: [
        if (pickup.locationName != null) InfoRow('Lieu', pickup.locationName!),
        if (pickup.expiresAt != null)
          InfoRow('À retirer avant', formatDateTime(pickup.expiresAt)),
        if (pickup.collectedAt != null)
          InfoRow('Retirée le', formatDateTime(pickup.collectedAt)),
        ...children,
      ],
    );
  }
}

class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    this.children = const [],
  });

  final Delivery? delivery;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final delivery = this.delivery;
    if (delivery == null) {
      return const SectionCard(
        title: 'Livraison',
        children: [
          Text('La livraison sera organisée une fois la commande payée.'),
        ],
      );
    }
    return SectionCard(
      title: 'Livraison ${delivery.number}',
      trailing: StatusStamp(delivery.status),
      children: [
        if (delivery.estimatedAt != null)
          InfoRow('Prévue vers', formatDateTime(delivery.estimatedAt)),
        if (delivery.deliveredAt != null)
          InfoRow('Livrée le', formatDateTime(delivery.deliveredAt)),
        if (delivery.failureReason.isNotEmpty)
          InfoRow('Incident', delivery.failureReason),
        if (delivery.steps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space8),
          for (final step in delivery.steps.reversed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.circle,
                size: 10,
                color: AppColors.primary,
              ),
              title: Text(commonStatusLabels[step.status] ?? step.status),
              subtitle: Text(
                [
                  formatDateTime(step.at),
                  step.note,
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
            ),
        ],
        ...children,
      ],
    );
  }
}
