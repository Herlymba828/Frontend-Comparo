import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'merchant_repository.dart';
import 'product_picker_field.dart';

/// Stock declared per product (reserved at order time).
const _stockStatuses = {
  'available': 'Disponible',
  'limited': 'Stock limité',
  'unavailable': 'Rupture',
  'discontinued': 'Arrêté',
};

class MerchantStockScreen extends ConsumerWidget {
  const MerchantStockScreen({super.key, required this.shopId});

  final int shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> edit({StockLine? line}) async {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => _StockDialog(shopId: shopId, line: line),
      );
      if (saved == true) {
        ref.invalidate(shopStockProvider(shopId));
      }
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Déclarer un stock'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shopStockProvider(shopId)),
        child: AsyncBody<List<StockLine>>(
          value: ref.watch(shopStockProvider(shopId)),
          onRetry: () => ref.invalidate(shopStockProvider(shopId)),
          builder: (lines) => lines.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_outlined,
                  title: 'Aucune disponibilité déclarée.',
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space16,
                    96,
                  ),
                  children: [
                    for (final line in lines)
                      Card(
                        child: ListTile(
                          title: Text(line.productName),
                          subtitle: line.quantity == null
                              ? null
                              : Text('Quantité : ${line.quantity}'),
                          trailing: StatusStamp(line.status),
                          onTap: () => edit(line: line),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StockDialog extends ConsumerStatefulWidget {
  const _StockDialog({required this.shopId, this.line});

  final int shopId;
  final StockLine? line;

  @override
  ConsumerState<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends ConsumerState<_StockDialog> {
  late NamedRef? _product = widget.line == null
      ? null
      : NamedRef(widget.line!.productId, widget.line!.productName);
  late String _status = _stockStatuses.containsKey(widget.line?.status)
      ? widget.line!.status
      : 'available';
  late final _quantity = TextEditingController(
    text: widget.line?.quantity ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Disponibilité'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.line == null)
            ProductPickerField(
              value: _product,
              onChanged: (product) => setState(() => _product = product),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.line!.productName),
            ),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'État'),
            items: [
              for (final entry in _stockStatuses.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          TextField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantité disponible (facultatif)',
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
          onPressed: _saving ? null : _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_product == null) {
      showInfo(context, 'Choisissez un produit.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(merchantRepositoryProvider)
          .setStock(
            shopId: widget.shopId,
            productId: _product!.id,
            status: _status,
            quantity: _quantity.text.trim().replaceAll(',', '.'),
            existingId: widget.line?.id,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'Disponibilité non enregistrée.');
        setState(() => _saving = false);
      }
    }
  }
}
