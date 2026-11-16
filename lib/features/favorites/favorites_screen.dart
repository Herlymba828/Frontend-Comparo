import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import 'favorites_repository.dart';

/// "Mes favoris": the products and the shops the user follows.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes favoris'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Produits'),
              Tab(text: 'Commerces'),
            ],
          ),
        ),
        body: SignedInGate(
          signInMessage: 'Connectez-vous pour retrouver vos favoris.',
          builder: (user) =>
              const TabBarView(children: [_ProductsTab(), _ShopsTab()]),
        ),
      ),
    );
  }
}

/// "−8 %" / "+4 %": the move since the product was followed, as the API gave
/// it ("-8.5"); null when the API did not say.
String? formatTrendPercent(String? changePercent, PriceTrend? trend) {
  if (trend == null || trend == PriceTrend.stable) {
    return trend == PriceTrend.stable ? 'Stable' : null;
  }
  final value = double.tryParse(changePercent ?? '');
  if (value == null) {
    return null;
  }
  final size = value.abs();
  final text = size == size.roundToDouble()
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(1).replaceAll('.', ',');
  final sign = trend == PriceTrend.down ? '−' : '+';
  return '$sign$text % depuis l’ajout';
}

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(favoriteProductsProvider),
      child: AsyncBody<List<FavoriteProduct>>(
        value: ref.watch(favoriteProductsProvider),
        onRetry: () => ref.invalidate(favoriteProductsProvider),
        builder: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.favorite_border,
                title: 'Aucun produit en favori.',
                message:
                    'Touchez le cœur d’une fiche produit pour suivre son '
                    'prix et le retrouver ici.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) =>
                    _FavoriteProductTile(favorite: items[index]),
              ),
      ),
    );
  }
}

class _FavoriteProductTile extends ConsumerWidget {
  const _FavoriteProductTile({required this.favorite});

  final FavoriteProduct favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = favorite.product;
    final trend = formatTrendPercent(favorite.changePercent, favorite.trend);
    final hasPrice = (product.priceSnapshot ?? '').trim().isNotEmpty;
    final trendColor = switch (favorite.trend) {
      PriceTrend.down => AppColors.primary,
      PriceTrend.up => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    return MarketSurface(
      onTap: () => context.push('/product/${product.id}'),
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 56,
              child: ProductArtwork(
                url: product.imageUrl,
                name: product.name,
                unitSize: 56,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  hasPrice
                      ? 'dès ${formatPrice(product.priceSnapshot, product.priceSnapshotCurrency)}'
                      : 'Prix non renseigné',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (trend != null)
                  Text(
                    trend,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: trendColor),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer des favoris',
            icon: const Icon(Icons.favorite, color: AppColors.error),
            onPressed: () async {
              try {
                await ref
                    .read(favoritesRepositoryProvider)
                    .unfollowProduct(product.id);
                ref
                  ..invalidate(favoriteProductsProvider)
                  ..invalidate(favoriteIdsProvider);
                if (context.mounted) {
                  showInfo(context, 'Retiré de vos favoris.');
                }
              } catch (error) {
                if (context.mounted) {
                  showApiError(context, error);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ShopsTab extends ConsumerWidget {
  const _ShopsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(favoriteShopsProvider),
      child: AsyncBody<List<FavoriteShop>>(
        value: ref.watch(favoriteShopsProvider),
        onRetry: () => ref.invalidate(favoriteShopsProvider),
        builder: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Aucun commerce en favori.',
                message:
                    'Touchez le cœur sur une offre pour suivre le commerce '
                    'qui la propose.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) =>
                    _FavoriteShopTile(shop: items[index]),
              ),
      ),
    );
  }
}

class _FavoriteShopTile extends ConsumerWidget {
  const _FavoriteShopTile({required this.shop});

  final FavoriteShop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = shop.offerCount == 1
        ? '1 offre en ce moment'
        : '${shop.offerCount} offres en ce moment';
    return MarketSurface(
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  shop.isVerified ? '$offers · boutique vérifiée' : offers,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ne plus suivre ce commerce',
            icon: const Icon(Icons.favorite, color: AppColors.error),
            onPressed: () async {
              try {
                await ref
                    .read(favoritesRepositoryProvider)
                    .unfollowShop(shop.merchantId);
                ref
                  ..invalidate(favoriteShopsProvider)
                  ..invalidate(favoriteIdsProvider);
                if (context.mounted) {
                  showInfo(context, 'Commerce retiré de vos favoris.');
                }
              } catch (error) {
                if (context.mounted) {
                  showApiError(context, error);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
