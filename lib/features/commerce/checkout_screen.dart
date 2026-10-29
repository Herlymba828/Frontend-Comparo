import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'commerce_models.dart';
import 'commerce_repository.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commande')),
      body: SignedInGate(builder: (user) => const _CheckoutBody()),
    );
  }
}

class _CheckoutBody extends ConsumerStatefulWidget {
  const _CheckoutBody();

  @override
  ConsumerState<_CheckoutBody> createState() => _CheckoutBodyState();
}

class _CheckoutBodyState extends ConsumerState<_CheckoutBody> {
  String _mode = 'delivery';
  int? _addressId;
  int? _locationId;
  final _notes = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return AsyncBody<Cart>(
      value: cart,
      onRetry: () => ref.invalidate(cartProvider),
      builder: (cart) => ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          SectionCard(
            title: 'Récapitulatif',
            children: [
              for (final item in cart.items)
                InfoRow(
                  '${double.tryParse(item.quantity)?.round() ?? 1} ×',
                  '${item.productName} — ${formatPrice(item.lineTotal, item.currency)}',
                ),
              const Divider(),
              InfoRow('Sous-total', formatPrice(cart.total, cart.currency)),
              const Text(
                'Les frais de livraison éventuels sont ajoutés à la commande.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          SectionCard(
            title: 'Mode de réception',
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'delivery',
                    icon: Icon(Icons.local_shipping_outlined),
                    label: Text('Livraison'),
                  ),
                  ButtonSegment(
                    value: 'pickup',
                    icon: Icon(Icons.storefront_outlined),
                    label: Text('Retrait'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (value) =>
                    setState(() => _mode = value.first),
              ),
              const SizedBox(height: AppSpacing.space12),
              if (_mode == 'delivery')
                _AddressPicker(
                  selected: _addressId,
                  onSelected: (id) => setState(() => _addressId = id),
                )
              else if (cart.merchantId == null)
                const Text('Le marchand du panier est inconnu.')
              else
                _LocationPicker(
                  merchantId: cart.merchantId!,
                  selected: _locationId,
                  onSelected: (id) => setState(() => _locationId = id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Instructions (facultatif)',
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.check),
            label: const Text('Valider la commande'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit({bool acceptPriceChanges = false}) async {
    if (_mode == 'delivery' && _addressId == null) {
      showInfo(context, 'Choisissez ou ajoutez une adresse de livraison.');
      return;
    }
    if (_mode == 'pickup' && _locationId == null) {
      showInfo(context, 'Choisissez un point de retrait.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final order = await ref
          .read(commerceRepositoryProvider)
          .checkout(
            deliveryMode: _mode,
            addressId: _mode == 'delivery' ? _addressId : null,
            pickupLocationId: _mode == 'pickup' ? _locationId : null,
            notes: _notes.text.trim(),
            acceptPriceChanges: acceptPriceChanges,
          );
      ref
        ..invalidate(cartProvider)
        ..invalidate(myOrdersProvider);
      if (mounted) {
        context.pushReplacement('/orders/${order.id}');
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'price_changed' && !acceptPriceChanges) {
        setState(() => _submitting = false);
        final accepted = await _confirmNewPrices(
          context,
          error.fields?['changes'],
        );
        if (accepted && mounted) {
          await _submit(acceptPriceChanges: true);
        } else {
          ref.invalidate(cartProvider);
        }
        return;
      }
      showApiError(context, error, 'La commande n’a pas pu être créée.');
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'La commande n’a pas pu être créée.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

/// Shows the prices that moved since the items were added; true to order at
/// the new prices.
Future<bool> _confirmNewPrices(BuildContext context, Object? rawChanges) async {
  final changes = rawChanges is List ? rawChanges : const [];
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Des prix ont changé'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Depuis l’ajout au panier :'),
          const SizedBox(height: AppSpacing.space8),
          for (final change in changes.whereType<Map>())
            Text(
              '• ${change['product']} : ${change['old_price']} → '
              '${change['new_price']} ${change['currency']}',
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Revoir le panier'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Commander à ces prix'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _AddressPicker extends ConsumerWidget {
  const _AddressPicker({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    return addresses.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Text(errorText(error)),
      data: (items) {
        if (selected == null && items.isNotEmpty) {
          final preferred = items.where((a) => a.isDefault).firstOrNull;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onSelected((preferred ?? items.first).id),
          );
        }
        return RadioGroup<int>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null) {
              onSelected(value);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final address in items)
                RadioListTile<int>(
                  contentPadding: EdgeInsets.zero,
                  value: address.id,
                  title: Text(address.summary),
                  subtitle: Text(
                    [
                      address.recipientName,
                      address.phone,
                    ].where((part) => part.isNotEmpty).join(' · '),
                  ),
                ),
              TextButton.icon(
                onPressed: () async {
                  final created = await showDialog<DeliveryAddress>(
                    context: context,
                    builder: (context) => const AddressFormDialog(),
                  );
                  if (created != null) {
                    ref.invalidate(addressesProvider);
                    onSelected(created.id);
                  }
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Ajouter une adresse'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationPicker extends ConsumerWidget {
  const _LocationPicker({
    required this.merchantId,
    required this.selected,
    required this.onSelected,
  });

  final int merchantId;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(shopLocationsProvider(merchantId));
    return locations.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Text(errorText(error)),
      data: (items) => items.isEmpty
          ? const Text('Ce marchand ne propose pas de point de retrait.')
          : RadioGroup<int>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) {
                  onSelected(value);
                }
              },
              child: Column(
                children: [
                  for (final location in items)
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: location.id,
                      title: Text(location.name),
                      subtitle: Text('${location.street} · ${location.city}'),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Creates a delivery address; pops with the created address.
class AddressFormDialog extends ConsumerStatefulWidget {
  const AddressFormDialog({super.key});

  @override
  ConsumerState<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends ConsumerState<AddressFormDialog> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Maison');
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController(text: 'Libreville');
  final _info = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_label, _name, _phone, _street, _city, _info]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle adresse'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(labelText: 'Nom (Maison…)'),
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Destinataire'),
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              TextFormField(
                controller: _street,
                validator: _required,
                decoration: const InputDecoration(labelText: 'Rue / quartier'),
              ),
              TextFormField(
                controller: _city,
                validator: _required,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              TextFormField(
                controller: _info,
                decoration: const InputDecoration(
                  labelText: 'Repère (facultatif)',
                ),
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
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final address = await ref
          .read(commerceRepositoryProvider)
          .createAddress(
            label: _label.text.trim(),
            recipientName: _name.text.trim(),
            phone: _phone.text.trim(),
            street: _street.text.trim(),
            city: _city.text.trim(),
            additionalInfo: _info.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context, address);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'Adresse non enregistrée.');
        setState(() => _saving = false);
      }
    }
  }
}
