import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import 'merchant_repository.dart';
import 'product_picker_field.dart';

/// The shop's prices and the offers customers can order.
class MerchantOffersScreen extends ConsumerStatefulWidget {
  const MerchantOffersScreen({super.key, required this.shopId});

  final int shopId;

  @override
  ConsumerState<MerchantOffersScreen> createState() =>
      MerchantOffersScreenState();
}

class MerchantOffersScreenState extends ConsumerState<MerchantOffersScreen> {
  final _busy = <int>{};

  void _refresh() {
    ref
      ..invalidate(shopPricesProvider(widget.shopId))
      ..invalidate(shopOffersProvider(widget.shopId));
  }

  @override
  Widget build(BuildContext context) {
    final prices = ref.watch(shopPricesProvider(widget.shopId));
    final offers = ref.watch(shopOffersProvider(widget.shopId));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (context) => _NewOfferDialog(shopId: widget.shopId),
          );
          if (created == true) {
            _refresh();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle offre'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: AsyncBody<List<ShopPrice>>(
          value: prices,
          onRetry: _refresh,
          builder: (prices) {
            final offersByProduct = <int, ShopOffer>{
              for (final offer in offers.value ?? const <ShopOffer>[])
                offer.productId: offer,
            };
            if (prices.isEmpty) {
              return const EmptyState(
                icon: Icons.sell_outlined,
                title: 'Aucune offre pour le moment.',
                message: 'Ajoutez vos prix : ils sont vérifiés puis comparés.',
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space16,
                AppSpacing.space16,
                96,
              ),
              itemCount: prices.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.space8),
              itemBuilder: (context, index) {
                final price = prices[index];
                final offer = offersByProduct[price.productId];
                return MarketSurface(
                  padding: const EdgeInsets.all(AppSpacing.space12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              price.productName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          PriceTag(
                            label: formatPrice(price.amount, price.currency),
                            caption:
                                '${formatQuantity(price.quantity)} ${price.unit}',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space8),
                      Wrap(
                        spacing: AppSpacing.space8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusStamp(price.status),
                          if (offer != null)
                            StatusStamp(
                              !offer.isActive
                                  ? 'pending'
                                  : price.status == 'published'
                                  ? 'active'
                                  : 'review',
                              labels: const {
                                'active': 'Offre en ligne',
                                'review': 'En ligne après validation',
                                'pending': 'Offre non publiée',
                              },
                            ),
                          if (price.status == 'draft' ||
                              price.status == 'review')
                            const Text(
                              'Validation par un modérateur en cours.',
                            ),
                          if (offer != null &&
                              !offer.isActive &&
                              price.status == 'published')
                            FilledButton(
                              onPressed: _busy.contains(offer.id)
                                  ? null
                                  : () => _publish(offer),
                              child: const Text('Publier l’offre'),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _publish(ShopOffer offer) async {
    setState(() => _busy.add(offer.id));
    try {
      await ref.read(merchantRepositoryProvider).publishOffer(offer.id);
      _refresh();
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(offer.id));
      }
    }
  }
}

class _NewOfferDialog extends ConsumerStatefulWidget {
  const _NewOfferDialog({required this.shopId});

  final int shopId;

  @override
  ConsumerState<_NewOfferDialog> createState() => _NewOfferDialogState();
}

class _NewOfferDialogState extends ConsumerState<_NewOfferDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _label = TextEditingController();
  NamedRef? _product;
  int? _priceType;
  int? _unit;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _quantity.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(priceTypesProvider).value ?? const <NamedRef>[];
    final units = ref.watch(unitsProvider).value ?? const <NamedRef>[];
    _priceType ??= types.firstOrNull?.id;
    return AlertDialog(
      title: const Text('Nouvelle offre'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProductPickerField(
                value: _product,
                onChanged: (product) => setState(() => _product = product),
              ),
              DropdownButtonFormField<int>(
                initialValue: _priceType,
                decoration: const InputDecoration(labelText: 'Type de prix'),
                items: [
                  for (final type in types)
                    DropdownMenuItem(value: type.id, child: Text(type.name)),
                ],
                validator: (value) => value == null ? 'Obligatoire.' : null,
                onChanged: (value) => setState(() => _priceType = value),
              ),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Prix (XAF)'),
                validator: _positive,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Quantité'),
                      validator: _positive,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unité'),
                      items: [
                        for (final unit in units)
                          DropdownMenuItem(
                            value: unit.id,
                            child: Text(
                              unit.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Obligatoire.' : null,
                      onChanged: (value) => setState(() => _unit = value),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Libellé promo (facultatif)',
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
          child: const Text('Soumettre'),
        ),
      ],
    );
  }

  String? _positive(String? value) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    return number == null || number <= 0 ? 'Nombre positif attendu.' : null;
  }

  Future<void> _save() async {
    if (_product == null) {
      showInfo(context, 'Choisissez un produit.');
      return;
    }
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(merchantRepositoryProvider)
          .createOffer(
            shopId: widget.shopId,
            productId: _product!.id,
            priceTypeId: _priceType!,
            unitId: _unit!,
            amount: _amount.text.trim().replaceAll(',', '.'),
            quantity: _quantity.text.trim().replaceAll(',', '.'),
            label: _label.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context, true);
        showInfo(
          context,
          'Offre soumise : elle sera vérifiée avant publication.',
        );
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'Offre non enregistrée.');
        setState(() => _saving = false);
      }
    }
  }
}
