import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../catalog/models/catalog_product.dart';
import 'data/alert_repository.dart';

class CreatePriceAlertDialog extends ConsumerStatefulWidget {
  const CreatePriceAlertDialog({required this.product, super.key});

  final CatalogProduct product;

  @override
  ConsumerState<CreatePriceAlertDialog> createState() =>
      _CreatePriceAlertDialogState();
}

class _CreatePriceAlertDialogState
    extends ConsumerState<CreatePriceAlertDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _thresholdController;
  late final String _currency;
  String _triggerType = 'price_drop';
  bool _repeat = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _thresholdController = TextEditingController();
    _currency = widget.product.priceSnapshotCurrency?.trim().isNotEmpty == true
        ? widget.product.priceSnapshotCurrency!.trim()
        : 'XAF';
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  bool get _requiresThreshold =>
      _triggerType == 'price_drop' || _triggerType == 'price_target';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Suivre ${widget.product.name}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _triggerType,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: const [
                  DropdownMenuItem(
                    value: 'price_drop',
                    child: Text('Baisse sous un seuil'),
                  ),
                  DropdownMenuItem(
                    value: 'price_target',
                    child: Text('Prix cible atteint'),
                  ),
                  DropdownMenuItem(
                    value: 'price_change',
                    child: Text('Tout changement de prix'),
                  ),
                  DropdownMenuItem(
                    value: 'back_in_stock',
                    child: Text('Retour en stock'),
                  ),
                  DropdownMenuItem(
                    value: 'new_offer',
                    child: Text('Nouvelle offre'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() {
                        _triggerType = value ?? 'price_drop';
                        _errorMessage = null;
                      }),
              ),
              if (_requiresThreshold) ...[
                const SizedBox(height: AppSpacing.space12),
                TextFormField(
                  controller: _thresholdController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Prix seuil',
                    suffixText: _currency,
                  ),
                  validator: (value) {
                    if (!_requiresThreshold) {
                      return null;
                    }
                    final normalized = (value ?? '').trim().replaceAll(
                      ',',
                      '.',
                    );
                    final amount = double.tryParse(normalized);
                    if (amount == null || !amount.isFinite || amount <= 0) {
                      return 'Saisissez un montant positif.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.space8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Répéter après déclenchement'),
                value: _repeat,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _repeat = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.space8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer l’alerte'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final threshold = _requiresThreshold
          ? _thresholdController.text.trim().replaceAll(',', '.')
          : null;
      await ref
          .read(alertRepositoryProvider)
          .createAlert(
            productId: widget.product.id,
            triggerType: _triggerType,
            thresholdAmount: threshold,
            thresholdCurrency: _currency,
            repeat: _repeat,
          );
      ref.invalidate(userAlertsProvider);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error is ApiException
              ? error.userMessage
              : 'Impossible de créer cette alerte.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
