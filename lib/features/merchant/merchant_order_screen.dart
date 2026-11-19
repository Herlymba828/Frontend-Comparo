import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/idempotency.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/text_entry_dialog.dart';
import '../commerce/commerce_models.dart';
import '../commerce/commerce_repository.dart';
import '../commerce/order_sections.dart';
import 'merchant_repository.dart';

/// An order received by the shop: prepare and hand over the pickup, give
/// the delivery to a courier, refund. The customer's view is
/// OrderDetailScreen.
class MerchantOrderScreen extends ConsumerStatefulWidget {
  const MerchantOrderScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<MerchantOrderScreen> createState() =>
      _MerchantOrderScreenState();
}

class _MerchantOrderScreenState extends ConsumerState<MerchantOrderScreen> {
  bool _busy = false;

  MerchantRepository get _merchant => ref.read(merchantRepositoryProvider);

  void _refresh() {
    ref
      ..invalidate(orderProvider(widget.orderId))
      ..invalidate(orderFulfilmentProvider(widget.orderId))
      ..invalidate(shopOrdersProvider);
  }

  final _actionKeys = ActionKeys();

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (mounted) {
        showInfo(context, success);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Commande reçue')),
      body: SignedInGate(
        role: 'merchant',
        builder: (user) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: AsyncBody<CustomerOrder>(
            value: order,
            onRetry: _refresh,
            builder: (order) {
              final fulfilment = ref.watch(
                orderFulfilmentProvider(widget.orderId),
              );
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                children: [
                  OrderSummaryCard(order: order),
                  const SizedBox(height: AppSpacing.space12),
                  fulfilment.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => Text(errorText(error)),
                    data: (data) => Column(
                      children: [
                        _paymentSection(data.payment),
                        const SizedBox(height: AppSpacing.space12),
                        if (order.isPickup)
                          _pickupSection(data.pickup)
                        else
                          _deliverySection(data.delivery),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Payment ─────────────────────────────────────────────────────────────
  Widget _paymentSection(Payment? payment) {
    if (payment == null) {
      return const SectionCard(
        title: 'Paiement',
        children: [Text('Le client n’a pas encore payé.')],
      );
    }
    return PaymentCard(
      payment: payment,
      actions: [
        if (payment.isRefundable)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _refund(payment),
            icon: const Icon(Icons.undo),
            label: const Text('Rembourser'),
          ),
      ],
    );
  }

  Future<void> _refund(Payment payment) async {
    final remaining = payment.amountRemaining.isEmpty
        ? payment.amount
        : payment.amountRemaining;
    final text = await showTextEntry(
      context,
      title: 'Rembourser le client ?',
      label: 'Motif (communiqué au client)',
      confirmLabel: 'Rembourser',
      maxLength: 200,
      intro: Text(
        'Le montant restant (${formatPrice(remaining, payment.currency)}) '
        'est remboursé et la commande annulée si elle n’est pas livrée.',
      ),
    );
    if (text != null) {
      final reason = text.isEmpty ? 'Remboursement marchand' : text;
      final action = (payment.number, reason);
      await _run(() async {
        await ref
            .read(commerceRepositoryProvider)
            .refundPayment(
              payment.number,
              reason: reason,
              idempotencyKey: _actionKeys.keyFor(action),
            );
        _actionKeys.succeeded(action);
      }, 'Remboursement enregistré.');
    }
  }

  // ── Pickup ──────────────────────────────────────────────────────────────
  Widget _pickupSection(Pickup? pickup) => PickupCard(
    pickup: pickup,
    children: [
      if (pickup != null)
        Wrap(
          spacing: AppSpacing.space8,
          children: [
            if (pickup.status == 'pending')
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => _merchant.markPickupReady(pickup.id),
                        'Le client est prévenu que sa commande est prête.',
                      ),
                child: const Text('Commande prête'),
              ),
            if (pickup.status == 'ready')
              FilledButton(
                onPressed: _busy ? null : () => _confirmPickup(pickup),
                child: const Text('Remise au client'),
              ),
          ],
        ),
    ],
  );

  Future<void> _confirmPickup(Pickup pickup) async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _PickupCodeDialog(),
    );
    if (code == null || code.trim().isEmpty) {
      return;
    }
    await _run(
      () => _merchant.confirmPickup(pickup.id, code),
      'Retrait confirmé.',
    );
  }

  // ── Delivery ────────────────────────────────────────────────────────────
  Widget _deliverySection(Delivery? delivery) => DeliveryCard(
    delivery: delivery,
    children: [
      if (delivery != null && delivery.status == 'pending')
        FilledButton.icon(
          onPressed: _busy ? null : () => _assignCourier(delivery),
          icon: const Icon(Icons.delivery_dining),
          label: const Text('Confier à un coursier'),
        ),
    ],
  );

  Future<void> _assignCourier(Delivery delivery) async {
    final courierId = await showDialog<int>(
      context: context,
      builder: (context) => const _CourierPickerDialog(),
    );
    if (courierId == null) {
      return;
    }
    await _run(
      () => _merchant.assignCourier(delivery.id, courierId),
      'Coursier assigné.',
    );
  }
}

class _PickupCodeDialog extends StatefulWidget {
  const _PickupCodeDialog();

  @override
  State<_PickupCodeDialog> createState() => _PickupCodeDialogState();
}

class _PickupCodeDialogState extends State<_PickupCodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Code de retrait du client'),
      content: TextField(
        controller: _code,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'PKP-XXXXXX'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _code.text),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

class _CourierPickerDialog extends ConsumerWidget {
  const _CourierPickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couriers = ref.watch(availableCouriersProvider);
    return AlertDialog(
      title: const Text('Choisir un coursier'),
      content: SizedBox(
        width: 360,
        child: couriers.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text(errorText(error)),
          data: (items) => items.isEmpty
              ? const Text('Aucun coursier disponible pour le moment.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final courier in items)
                      ListTile(
                        leading: const Icon(Icons.delivery_dining),
                        title: Text(courier.name),
                        subtitle: Text(
                          '${courier.vehicleLabel} · ${courier.activeDeliveries} en cours'
                          '${courier.phone.isEmpty ? '' : ' · ${courier.phone}'}',
                        ),
                        onTap: () => Navigator.pop(context, courier.userId),
                      ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
