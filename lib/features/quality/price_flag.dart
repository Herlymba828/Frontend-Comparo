import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/network/json_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../identity/data/auth_providers.dart';

/// Why a user thinks a shown price is wrong (`POST /api/quality/flags/`).
enum FlagReason {
  wrongAmount('wrong_amount', 'Le prix en magasin est différent'),
  unavailable('unavailable', 'Produit introuvable ou en rupture'),
  wrongProduct('wrong_product', 'Mauvais produit ou mauvais format'),
  other('other', 'Autre');

  const FlagReason(this.code, this.label);

  final String code;
  final String label;
}

/// Longest comment the API accepts.
const maxFlagComment = 500;

/// The price a user saw in the shop, as the API wants it ("1234.50").
/// Null when the field is empty; a [FormatException] says why it is refused.
String? parseSeenAmount(String raw) {
  final text = raw.trim().replaceAll(' ', '').replaceAll(' ', '');
  if (text.isEmpty) {
    return null;
  }
  final match = RegExp(r'^(\d{1,10})(?:[.,](\d{1,2}))?$').firstMatch(text);
  if (match == null) {
    throw const FormatException(
      'Saisissez un montant, par exemple 1250 (2 décimales au plus).',
    );
  }
  final amount =
      '${match.group(1)}${match.group(2) == null ? '' : '.${match.group(2)}'}';
  if ((double.tryParse(amount) ?? 0) <= 0) {
    throw const FormatException('Le montant doit être supérieur à zéro.');
  }
  return amount;
}

final priceFlagRepositoryProvider = Provider<PriceFlagRepository>(
  (ref) => PriceFlagRepository(ref.watch(jsonApiProvider)),
);

class PriceFlagRepository {
  const PriceFlagRepository(this._api);

  final JsonApi _api;

  /// Adds the user's flag to the open dossier of the offer's price. The API
  /// refuses (409) a second flag from the same user.
  Future<void> flag({
    required int offerId,
    required FlagReason reason,
    String? seenAmount,
    String comment = '',
  }) => _api.send(
    'api/quality/flags/',
    data: {
      'offer_id': offerId,
      'reason': reason.code,
      'observed_amount': seenAmount,
      'comment': comment.trim(),
    },
  );
}

/// Opens the flag sheet for an offer; a visitor signs in first.
Future<void> showPriceFlagSheet(
  BuildContext context,
  WidgetRef ref, {
  required int offerId,
  required String merchantName,
}) async {
  final user = await ref.read(authSessionProvider.future);
  if (!context.mounted) {
    return;
  }
  if (user == null) {
    await context.push('/auth');
    return;
  }
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        PriceFlagSheet(offerId: offerId, merchantName: merchantName),
  );
  if (sent == true && context.mounted) {
    showInfo(context, 'Merci : la modération va vérifier ce prix.');
  }
}

/// The form of a flag: a reason, the price seen in the shop, a comment.
class PriceFlagSheet extends ConsumerStatefulWidget {
  const PriceFlagSheet({
    super.key,
    required this.offerId,
    required this.merchantName,
  });

  final int offerId;
  final String merchantName;

  @override
  ConsumerState<PriceFlagSheet> createState() => _PriceFlagSheetState();
}

class _PriceFlagSheetState extends ConsumerState<PriceFlagSheet> {
  final _amount = TextEditingController();
  final _comment = TextEditingController();
  FlagReason _reason = FlagReason.wrongAmount;
  String? _amountError;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    String? seen;
    if (_reason == FlagReason.wrongAmount) {
      try {
        seen = parseSeenAmount(_amount.text);
      } on FormatException catch (error) {
        setState(() => _amountError = error.message);
        return;
      }
    }
    setState(() {
      _amountError = null;
      _busy = true;
    });
    try {
      await ref
          .read(priceFlagRepositoryProvider)
          .flag(
            offerId: widget.offerId,
            reason: _reason,
            seenAmount: seen,
            comment: _comment.text,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showApiError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space16,
        0,
        AppSpacing.space16,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Signaler ce prix',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Offre de ${widget.merchantName}. La modération vérifie ; '
              'votre nom n’est jamais montré au commerce.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.space8),
            RadioGroup<FlagReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value ?? _reason),
              child: Column(
                children: [
                  for (final reason in FlagReason.values)
                    RadioListTile<FlagReason>(
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      title: Text(reason.label),
                    ),
                ],
              ),
            ),
            if (_reason == FlagReason.wrongAmount) ...[
              const SizedBox(height: AppSpacing.space4),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Prix vu en magasin (FCFA), facultatif',
                  errorText: _amountError,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space12),
            TextField(
              controller: _comment,
              maxLength: maxFlagComment,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Un détail à ajouter ? (facultatif)',
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: const Text('Envoyer le signalement'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}
