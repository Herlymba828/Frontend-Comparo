import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/market_widgets.dart';
import '../catalog/data/catalog_providers.dart';
import '../catalog/models/catalog_product.dart';
import '../catalog/models/catalog_search_request.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final SearchController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = SearchController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryTreeProvider);
    const featuredRequest = CatalogSearchRequest(
      query: '',
      ordering: '-created_at',
      pageSize: 4,
    );
    final products = ref.watch(searchProductsProvider(featuredRequest));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 1.5),
                boxShadow: inkShadow(offset: 2, color: AppColors.terracotta),
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                color: AppColors.ink,
                size: 19,
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            const Flexible(
              child: Text('Comparateur Prix', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mes alertes',
            onPressed: () => context.push('/alerts'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Plus d’options',
            onSelected: (value) {
              if (value == 'clear-offline') {
                _confirmClearOfflineData();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear-offline',
                child: Text('Effacer les données hors ligne'),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 0),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 760
                ? AppSpacing.space32
                : AppSpacing.space16;
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.space24,
                  horizontalPadding,
                  AppSpacing.space48,
                ),
                children: [
                  _HomeHero(
                    searchController: _searchController,
                    onSearch: _openSearch,
                  ),
                  const SizedBox(height: AppSpacing.space24),
                  _SectionHeading(
                    title: 'Explorer par catégorie',
                    actionLabel: 'Tout voir',
                    onAction: () => context.push('/search'),
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  categories.when(
                    loading: () => const SizedBox(
                      height: 82,
                      child: Center(child: LinearProgressIndicator()),
                    ),
                    error: (error, stackTrace) => _SectionError(
                      message: 'Catégories indisponibles.',
                      onRetry: () => ref.invalidate(categoryTreeProvider),
                    ),
                    data: (tree) {
                      final items = _flattenCategories(tree).take(8).toList();
                      if (items.isEmpty) {
                        return const _EmptySection(
                          message:
                              'Aucune catégorie disponible pour le moment.',
                        );
                      }
                      return SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: AppSpacing.space8),
                          itemBuilder: (context, index) {
                            final category = items[index];
                            return _CategoryTile(
                              category: category,
                              onTap: () => context.push(
                                Uri(
                                  path: '/search',
                                  queryParameters: {'category': category.slug},
                                ).toString(),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.space24),
                  _SectionHeading(
                    title: 'À découvrir',
                    actionLabel: 'Voir tout',
                    onAction: () => context.push('/search'),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    'Les nouveautés du catalogue et leur meilleur prix connu.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  products.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppSpacing.space32,
                      ),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) => _SectionError(
                      message: 'Impossible de charger les produits.',
                      onRetry: () => ref.invalidate(
                        searchProductsProvider(featuredRequest),
                      ),
                    ),
                    data: (result) {
                      final items = result.value.results.take(4).toList();
                      if (items.isEmpty) {
                        return const _EmptySection(
                          message: 'Aucun produit disponible pour le moment.',
                        );
                      }
                      final columns = constraints.maxWidth >= 980
                          ? 4
                          : constraints.maxWidth >= 640
                          ? 3
                          : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: AppSpacing.space16,
                          mainAxisSpacing: AppSpacing.space16,
                          childAspectRatio: columns == 2 ? 0.6 : 0.78,
                        ),
                        itemBuilder: (context, index) => _CatalogProductCard(
                          product: items[index],
                          onTap: () =>
                              context.push('/product/${items[index].id}'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClearOfflineData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer les données hors ligne ?'),
        content: const Text(
          'Les recherches, fiches et offres enregistrées sur cet appareil '
          'seront supprimées. Votre session et vos préférences sont conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(catalogRepositoryProvider).clearOfflineCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Données hors ligne effacées.')),
      );
    }
  }

  void _openSearch(String value) {
    FocusScope.of(context).unfocus();
    final query = value.trim();
    context.push(
      query.isEmpty
          ? '/search'
          : Uri(path: '/search', queryParameters: {'query': query}).toString(),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.searchController, required this.onSearch});

  final SearchController searchController;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: const SizedBox(
                height: 12,
                width: double.infinity,
                child: OverflowBox(
                  minHeight: 120,
                  maxHeight: 120,
                  child: WaxPattern(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            Text(
              'Prix du jour',
              style: AppTextStyles.display.copyWith(
                fontSize: compact ? 38 : 48,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Transform.rotate(
              angle: -0.035,
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.terracotta,
                  ),
                  SizedBox(width: AppSpacing.space4),
                  Flexible(
                    child: Text(
                      'comparés près de chez vous',
                      style: AppTextStyles.handNote,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: inkShadow(),
              ),
              child: TextField(
                controller: searchController,
                onSubmitted: onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit (ex. riz, huile)',
                  prefixIcon: const Icon(Icons.search, color: AppColors.ink),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.ink,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Tooltip(
                      message: 'Rechercher',
                      child: FilledButton(
                        onPressed: () => onSearch(searchController.text),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: AppColors.accent,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.space16,
                          ),
                        ),
                        child: compact
                            ? const Icon(
                                Icons.arrow_forward,
                                semanticLabel: 'Rechercher',
                              )
                            : const Text('Rechercher'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final CatalogCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(
        _categoryIcon(category.name),
        size: 18,
        color: AppColors.primary,
      ),
      label: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
    );
  }
}

IconData _categoryIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('épicerie') ||
      value.contains('aliment') ||
      value.contains('fruit')) {
    return Icons.local_grocery_store_outlined;
  }
  if (value.contains('maison') || value.contains('ménage')) {
    return Icons.chair_outlined;
  }
  if (value.contains('électron') || value.contains('tech')) {
    return Icons.devices_outlined;
  }
  if (value.contains('beauté') || value.contains('santé')) {
    return Icons.spa_outlined;
  }
  return Icons.category_outlined;
}

Iterable<CatalogCategory> _flattenCategories(
  List<CatalogCategory> categories,
) sync* {
  for (final category in categories) {
    yield category;
    yield* _flattenCategories(category.children);
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message)),
        IconButton(
          tooltip: 'Réessayer',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space16),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({required this.product, required this.onTap});

  final CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPrice =
        product.priceSnapshot != null &&
        product.priceSnapshot!.trim().isNotEmpty;
    return MarketSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductArtwork(url: product.imageUrl, unitSize: 96),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.space8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.ink),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          product.category?.name ?? 'Produit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.ink),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            'Meilleur prix connu',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          PriceTag(
            label: formatPrice(
              product.priceSnapshot,
              product.priceSnapshotCurrency,
            ),
            muted: !hasPrice,
          ),
          if (product.isVerified || product.availability == 'available')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space8),
              child: Wrap(
                spacing: AppSpacing.space4,
                runSpacing: AppSpacing.space4,
                children: [
                  if (product.isVerified)
                    const StampBadge(
                      label: 'Vérifié',
                      icon: Icons.check,
                      angle: -2,
                    ),
                  if (product.availability == 'available')
                    const StampBadge(
                      label: 'Disponible',
                      color: AppColors.info,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
