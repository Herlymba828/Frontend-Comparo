import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/text_entry_dialog.dart';
import 'cash_repository.dart';
import 'cash_scanner.dart';
import 'commerce_models.dart';

/// Scans the payer's QR code: returns its content, or null when cancelled.
typedef CashScanner = Future<String?> Function(BuildContext context);

/// The payer's side of a cash payment: confirm the handover, or show a QR code
/// that the collector scans to confirm both sides at once.
class CustomerCashActions extends ConsumerStatefulWidget {
  const CustomerCashActions({
    super.key,
    required this.payment,
    required this.onChanged,
  });

  final Payment payment;
  final VoidCallback onChanged;

  @override
  ConsumerState<CustomerCashActions> createState() =>
      _CustomerCashActionsState();
}

class _CustomerCashActionsState extends ConsumerState<CustomerCashActions> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(cashRepositoryProvider)
          .payerConfirm(widget.payment.number);
      widget.onChanged();
      if (mounted) {
        showInfo(
          context,
          'Remise confirmée. Il reste la confirmation de '
          'celui qui encaisse.',
        );
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
    final payment = widget.payment;
    if (!payment.awaitsHandover) {
      return const SizedBox.shrink();
    }
    final confirmed = payment.payerConfirmedAt != null;
    final disputed = payment.cashOutcome == 'disputed';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            disputed
                ? 'Litige en cours : le support va trancher. Vous gardez '
                      'votre commande.'
                : confirmed
                ? 'Vous avez confirmé la remise. Réception en attente de '
                      'celui qui encaisse (48 h au plus, sinon le support '
                      'tranche).'
                : 'Payez en espèces à la remise, puis confirmez-le. Celui '
                      'qui encaisse le confirme de son côté.',
          ),
          if (!disputed) ...[
            const SizedBox(height: AppSpacing.space8),
            Wrap(
              spacing: AppSpacing.space8,
              children: [
                if (!confirmed)
                  FilledButton.icon(
                    onPressed: _busy ? null : _confirm,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('J’ai remis l’argent'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) =>
                        CashQrDialog(paymentNumber: payment.number),
                  ),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Afficher mon code QR'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The payer's code, to show to the collector. It lives a few minutes: a new
/// one is requested on demand.
class CashQrDialog extends ConsumerStatefulWidget {
  const CashQrDialog({super.key, required this.paymentNumber});

  final String paymentNumber;

  @override
  ConsumerState<CashQrDialog> createState() => _CashQrDialogState();
}

class _CashQrDialogState extends ConsumerState<CashQrDialog> {
  late Future<CashQr> _qr = _load();

  Future<CashQr> _load() =>
      ref.read(cashRepositoryProvider).qr(widget.paymentNumber);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Votre code QR'),
    content: FutureBuilder<CashQr>(
      future: _qr,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Le code n’a pas pu être créé. Réessayez.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        final qr = snapshot.data;
        if (qr == null) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: QrImageView(
                data: qr.token,
                backgroundColor: Colors.white,
                semanticsLabel: 'Code QR de remise d’espèces',
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              'Montrez-le à celui qui encaisse après lui avoir remis '
              'l’argent. Il expire dans ${qr.expiresInSeconds ~/ 60} min.',
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => setState(() => _qr = _load()),
        child: const Text('Nouveau code'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
    ],
  );
}

/// The collector's side (courier, or merchant at a pickup): what to collect,
/// and the three ways to answer: received, scan the payer's code, or nothing
/// received (which opens a dispute at once).
class CollectorCashCard extends ConsumerStatefulWidget {
  const CollectorCashCard({
    super.key,
    required this.cash,
    required this.onChanged,
    this.scanner = scanCashQr,
  });

  final CashSummary cash;
  final VoidCallback onChanged;
  final CashScanner scanner;

  @override
  ConsumerState<CollectorCashCard> createState() => _CollectorCashCardState();
}

class _CollectorCashCardState extends ConsumerState<CollectorCashCard> {
  bool _busy = false;

  CashRepository get _repo => ref.read(cashRepositoryProvider);

  Future<void> _run(Future<Object?> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      widget.onChanged();
      if (mounted) {
        showInfo(context, done);
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

  Future<void> _scan() async {
    final token = await widget.scanner(context);
    if (token == null || token.isEmpty || !mounted) {
      return;
    }
    await _run(() => _repo.scan(token), 'Paiement confirmé par le code QR.');
  }

  Future<void> _deny() async {
    final reason = await showTextEntry(
      context,
      title: 'Rien reçu ?',
      label: 'Que s’est-il passé ?',
      confirmLabel: 'Signaler',
      intro: const Text(
        'Une réclamation s’ouvre aussitôt. Le client garde la commande ; '
        'en cas de doute, le support donne tort à celui qui encaisse.',
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }
    await _run(
      () => _repo.collectorDeny(widget.cash.number, reason),
      'Litige ouvert : le support va trancher.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cash = widget.cash;
    final amount = formatPrice(cash.amount, cash.currency);
    return SectionCard(
      title: 'Espèces à encaisser',
      children: [
        InfoRow('Montant', amount),
        if (!cash.isWaiting)
          Text(
            cash.status == 'captured'
                ? 'Paiement en espèces confirmé.'
                : 'Ce paiement est clos.',
          )
        else ...[
          Text(
            cash.isDisputed
                ? 'Litige en cours : le support va trancher.'
                : cash.collectorConfirmed
                ? 'Vous avez confirmé la réception. En attente du client.'
                : cash.payerConfirmed
                ? 'Le client dit vous avoir remis l’argent. Confirmez la '
                      'réception.'
                : 'Encaissez $amount à la remise, puis confirmez la '
                      'réception ou scannez le code du client.',
          ),
          if (!cash.isDisputed && !cash.collectorConfirmed) ...[
            const SizedBox(height: AppSpacing.space8),
            Wrap(
              spacing: AppSpacing.space8,
              runSpacing: AppSpacing.space8,
              children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => _repo.collectorConfirm(cash.number),
                          'Réception confirmée.',
                        ),
                  icon: const Icon(Icons.check),
                  label: const Text('J’ai reçu l’argent'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scanner le code du client'),
                ),
                TextButton(
                  onPressed: _busy ? null : _deny,
                  child: const Text('Je n’ai rien reçu'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
