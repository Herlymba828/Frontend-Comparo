import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import 'commerce_models.dart';
import 'commerce_repository.dart';
import 'order_sections.dart';

/// One of the customer's orders: pay, follow the pickup or the delivery,
/// cancel, report a problem. The merchant's view is MerchantOrderScreen.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;

  CommerceRepository get _repo => ref.read(commerceRepositoryProvider);

  void _refresh() {
    ref
      ..invalidate(orderProvider(widget.orderId))
      ..invalidate(orderFulfilmentProvider(widget.orderId))
      ..invalidate(myOrdersProvider);
  }

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
      appBar: AppBar(title: const Text('Commande')),
      body: SignedInGate(
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
                        _paymentSection(order, data.payment),
                        const SizedBox(height: AppSpacing.space12),
                        if (order.isPickup)
                          _pickupSection(data.pickup)
                        else
                          DeliveryCard(delivery: data.delivery),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  if (order.status == 'pending')
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _cancelOrder(order),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Annuler la commande'),
                    ),
                  TextButton.icon(
                    onPressed: () => context.push(
                      '/support?order=${Uri.encodeComponent(order.number)}',
                    ),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Signaler un problème'),
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
  Widget _paymentSection(CustomerOrder order, Payment? payment) {
    if (payment == null) {
      return SectionCard(
        title: 'Paiement',
        children: [
          if (order.status == 'pending')
            FilledButton.icon(
              onPressed: _busy ? null : () => _pay(order),
              icon: const Icon(Icons.payments_outlined),
              label: Text('Payer ${formatPrice(order.total, order.currency)}'),
            )
          else
            const Text('Aucun paiement pour cette commande.'),
        ],
      );
    }
    return PaymentCard(
      payment: payment,
      actions: [
        if (payment.isRetryable)
          _RetryButton(
            availableAt: payment.retryAvailableAt,
            onPressed: _busy
                ? null
                : () => _run(
                    () => _repo.retryPayment(payment.number),
                    'Nouvelle tentative envoyée.',
                  ),
          ),
        if (payment.isCancellable)
          OutlinedButton(
            onPressed: _busy ? null : () => _cancelPayment(payment),
            child: const Text('Annuler le paiement'),
          ),
      ],
      children: [
        if (payment.status == 'pending')
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space8),
            child: Text(
              payment.method == 'cash'
                  ? 'Paiement en espèces au retrait : le marchand le '
                        'confirmera lors de la remise.'
                  : 'Validez le paiement sur votre téléphone : la commande '
                        'sera confirmée dès la réponse du prestataire.',
            ),
          ),
      ],
    );
  }

  Future<void> _pay(CustomerOrder order) async {
    final choice = await showDialog<_PaymentChoice>(
      context: context,
      builder: (context) =>
          _PaymentMethodDialog(cashAllowed: order.deliveryMode == 'pickup'),
    );
    if (choice == null) {
      return;
    }
    await _run(
      () => _repo.initiatePayment(
        orderId: order.id,
        method: choice.method,
        provider: choice.provider,
        instrumentHint: choice.phone,
      ),
      'Paiement initié.',
    );
  }

  Future<void> _cancelPayment(Payment payment) async {
    final ok = await confirmAction(
      context,
      title: 'Annuler le paiement ?',
      message: 'La commande non payée sera annulée elle aussi.',
      confirmLabel: 'Annuler le paiement',
    );
    if (ok) {
      await _run(() => _repo.cancelPayment(payment.number), 'Paiement annulé.');
    }
  }

  Future<void> _cancelOrder(CustomerOrder order) async {
    final ok = await confirmAction(
      context,
      title: 'Annuler la commande ?',
      message: 'Un paiement en cours sera annulé avec elle.',
      confirmLabel: 'Annuler la commande',
    );
    if (ok) {
      await _run(() => _repo.cancelOrder(order.id), 'Commande annulée.');
    }
  }

  // ── Pickup ──────────────────────────────────────────────────────────────
  Widget _pickupSection(Pickup? pickup) => PickupCard(
    pickup: pickup,
    children: [
      if (pickup?.code != null &&
          (pickup?.status == 'pending' || pickup?.status == 'ready')) ...[
        const SizedBox(height: AppSpacing.space8),
        const Text('Présentez ce code au comptoir :'),
        const SizedBox(height: AppSpacing.space8),
        Center(
          child: PriceTag(
            label: pickup!.code!,
            style: AppTextStyles.pricePrimary,
            angle: 0,
          ),
        ),
      ],
    ],
  );
}

typedef _PaymentChoice = ({String method, String provider, String phone});

class _PaymentMethodDialog extends StatefulWidget {
  const _PaymentMethodDialog({required this.cashAllowed});

  /// Cash is paid at the shop: only for a pickup order.
  final bool cashAllowed;

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  String _provider = 'airtel_money';
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _provider != 'manual';
    return AlertDialog(
      title: const Text('Moyen de paiement'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<String>(
            groupValue: _provider,
            onChanged: (value) =>
                setState(() => _provider = value ?? _provider),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RadioListTile(
                  value: 'airtel_money',
                  title: Text('Airtel Money'),
                ),
                const RadioListTile(
                  value: 'moov_money',
                  title: Text('Moov Money'),
                ),
                if (widget.cashAllowed)
                  const RadioListTile(
                    value: 'manual',
                    title: Text('Espèces au retrait'),
                  ),
              ],
            ),
          ),
          if (mobile)
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'Numéro Mobile Money (facultatif)',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop<_PaymentChoice>(context, (
            method: mobile ? 'mobile_money' : 'cash',
            provider: _provider,
            phone: mobile ? _phone.text.trim() : '',
          )),
          child: const Text('Payer'),
        ),
      ],
    );
  }
}

/// "Réessayer" waits for the gateway's late answer after a timeout, with a
/// countdown instead of a click bound to fail.
class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.availableAt, required this.onPressed});

  final DateTime? availableAt;
  final VoidCallback? onPressed;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  Timer? _ticker;

  int get _secondsLeft {
    final at = widget.availableAt;
    if (at == null) {
      return 0;
    }
    final left = at.difference(DateTime.now()).inSeconds;
    return left > 0 ? left + 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    if (_secondsLeft > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft == 0) {
          timer.cancel();
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _secondsLeft;
    return FilledButton(
      onPressed: left > 0 ? null : widget.onPressed,
      child: Text(
        left > 0 ? 'Réessayer dans $left s' : 'Réessayer le paiement',
      ),
    );
  }
}
