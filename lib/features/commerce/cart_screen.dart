import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import 'commerce_models.dart';
import 'commerce_repository.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon panier')),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 2),
      body: SignedInGate(
        signInMessage: 'Connectez-vous pour remplir votre panier.',
        builder: (user) => const _CartBody(),
      ),
    );
  }
}

class _CartBody extends ConsumerStatefulWidget {
  const _CartBody();

  @override
  ConsumerState<_CartBody> createState() => _CartBodyState();
}

class _CartBodyState extends ConsumerState<_CartBody> {
  final _busy = <int>{};
  bool _validating = false;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(cartProvider),
      child: AsyncBody<Cart>(
        value: cart,
        onRetry: () => ref.invalidate(cartProvider),
        errorFallback: 'Impossible de charger votre panier.',
        builder: (cart) => cart.items.isEmpty
            ? EmptyState(
                icon: Icons.shopping_basket_outlined,
                title: 'Votre panier est vide.',
                message:
                    'Ouvrez une fiche produit et ajoutez une offre au panier.',
                action: OutlinedButton(
                  onPressed: () => context.go('/search'),
                  child: const Text('Chercher un produit'),
                ),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                children: [
                  for (final item in cart.items) ...[
                    _CartLine(
                      item: item,
                      busy: _busy.contains(item.id),
                      onQuantity: (quantity) => _setQuantity(item, quantity),
                      onRemove: () => _remove(item),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                  ],
                  const SizedBox(height: AppSpacing.space8),
                  MarketSurface(
                    padding: const EdgeInsets.all(AppSpacing.space16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total (${cart.itemCount} article(s))',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        PriceTag(
                          label: formatPrice(cart.total, cart.currency),
                          style: AppTextStyles.pricePrimary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  FilledButton.icon(
                    onPressed: _validating ? null : _checkout,
                    icon: _validating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline),
                    label: const Text('Passer la commande'),
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  TextButton(
                    onPressed: _clear,
                    child: const Text('Vider le panier'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _run(int id, Future<void> Function() action) async {
    setState(() => _busy.add(id));
    try {
      await action();
      ref.invalidate(cartProvider);
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'Impossible de modifier le panier.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(id));
      }
    }
  }

  void _setQuantity(CartItem item, String quantity) => _run(
    item.id,
    () =>
        ref.read(commerceRepositoryProvider).updateQuantity(item.id, quantity),
  );

  void _remove(CartItem item) => _run(
    item.id,
    () => ref.read(commerceRepositoryProvider).removeItem(item.id),
  );

  Future<void> _clear() async {
    final ok = await confirmAction(
      context,
      title: 'Vider le panier ?',
      message: 'Tous les articles seront retirés.',
      confirmLabel: 'Vider',
    );
    if (!ok) {
      return;
    }
    await _run(-1, () => ref.read(commerceRepositoryProvider).clearCart());
  }

  Future<void> _checkout() async {
    setState(() => _validating = true);
    try {
      final check = await ref.read(commerceRepositoryProvider).validateCart();
      if (!mounted) {
        return;
      }
      if (!check.valid) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Panier à corriger'),
            content: Text([...check.errors, ...check.warnings].join('\n')),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Compris'),
              ),
            ],
          ),
        );
        return;
      }
      context.push('/checkout');
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'Impossible de vérifier le panier.');
      }
    } finally {
      if (mounted) {
        setState(() => _validating = false);
      }
    }
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.busy,
    required this.onQuantity,
    required this.onRemove,
  });

  final CartItem item;
  final bool busy;
  final ValueChanged<String> onQuantity;
  final VoidCallback onRemove;

  int get _count => double.tryParse(item.quantity)?.round() ?? 1;

  @override
  Widget build(BuildContext context) {
    return MarketSurface(
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.productName, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '${formatPrice(item.unitPrice, item.currency)} l’unité',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (item.priceChanged)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space4),
              child: Text(
                'Le prix a changé : ${formatPrice(item.currentPrice, item.currency)}',
                style: const TextStyle(color: AppColors.warning),
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: 'Retirer un',
                onPressed: busy || _count <= 1
                    ? null
                    : () => onQuantity('${_count - 1}'),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_count', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                tooltip: 'Ajouter un',
                onPressed: busy ? null : () => onQuantity('${_count + 1}'),
                icon: const Icon(Icons.add_circle_outline),
              ),
              const Spacer(),
              Text(
                formatPrice(item.lineTotal, item.currency),
                style: AppTextStyles.priceSecondary,
              ),
              IconButton(
                tooltip: 'Retirer du panier',
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
