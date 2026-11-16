import 'package:comparo_ui/comparo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/formatters/age_formatter.dart';
import '../../core/storage/repository_result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comparo_logo.dart';
import '../../core/widgets/space_scaffold.dart';
import '../catalog/data/catalog_providers.dart';
import '../catalog/models/catalog_product.dart';
import '../catalog/models/catalog_product_page.dart';
import '../catalog/models/catalog_search_request.dart';
import '../commerce/basket_optimisation_screen.dart';
import '../commerce/commerce_repository.dart';
import '../identity/data/auth_providers.dart';

/// Products listed on the "Prix du jour" slate (the design allows 5 rows).
const _slateRequest = CatalogSearchRequest(
  query: '',
  ordering: '-created_at',
  pageSize: MarketSlate.maxRows,
);

/// What "Ma liste de la semaine" shows: the cart's size and its best total.
class _WeeklyList {
  const _WeeklyList({this.count = 0, this.best = 0, this.save = 0});

  final int count;
  final num best;
  final num save;
}

/// The signed-in user's list; null for a visitor (nothing to count).
final _weeklyListProvider = FutureProvider.autoDispose<_WeeklyList?>((
  ref,
) async {
  if (ref.watch(authSessionProvider).value == null) {
    return null;
  }
  final cart = await ref.watch(cartProvider.future);
  if (cart.itemCount == 0) {
    return const _WeeklyList();
  }
  final cartTotal = num.tryParse(cart.total) ?? 0;
  try {
    final plan = await ref.watch(basketOptimisationProvider(false).future);
    final best = plan.solutions.isEmpty ? null : plan.solutions.first;
    return _WeeklyList(
      count: cart.itemCount,
      best: num.tryParse(best?.total ?? '') ?? cartTotal,
      save: num.tryParse(best?.savings ?? '') ?? 0,
    );
  } on ApiException {
    // The comparison is optional: the list still shows what it holds.
    return _WeeklyList(count: cart.itemCount, best: cartTotal);
  }
});

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
    final products = ref.watch(searchProductsProvider(_slateRequest));

    return Scaffold(
      appBar: AppBar(
        title: const ComparoLogo(),
        actions: [
          const SpaceSwitcher(current: AppSpace.customer),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ComparoDims.space5,
              ComparoDims.space2,
              ComparoDims.space5,
              AppSpacing.space48,
            ),
            children: [
              Text(
                'Au marché aujourd’hui',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                'Les meilleurs prix connus, comparés pour vous',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.space16),
              _SearchField(
                controller: _searchController,
                onSearch: _openSearch,
              ),
              const SizedBox(height: AppSpacing.space16),
              _WeeklyListCard(
                list: ref.watch(_weeklyListProvider),
                onOpen: () => context.go('/cart'),
                onStart: () => context.go('/search'),
              ),
              const SizedBox(height: AppSpacing.space16),
              _PriceSlate(
                products: products,
                onRetry: () =>
                    ref.invalidate(searchProductsProvider(_slateRequest)),
                onOpen: (product) => context.push('/product/${product.id}'),
              ),
              const SizedBox(height: AppSpacing.space24),
              const SectionTitle('Explorer par catégorie'),
              const SizedBox(height: AppSpacing.space8),
              categories.when(
                loading: () => const SizedBox(
                  height: 48,
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
                      message: 'Aucune catégorie disponible pour le moment.',
                    );
                  }
                  return Wrap(
                    spacing: AppSpacing.space8,
                    runSpacing: AppSpacing.space8,
                    children: [
                      for (final category in items)
                        _CategoryTile(
                          category: category,
                          onTap: () => context.push(
                            Uri(
                              path: '/search',
                              queryParameters: {'category': category.slug},
                            ).toString(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSearch});

  final SearchController controller;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final colors = context.comparo;
    OutlineInputBorder pill(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(ComparoDims.radiusPill),
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      controller: controller,
      onSubmitted: onSearch,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Riz, huile, savon…',
        prefixIcon: Icon(Icons.search_rounded, color: colors.ink),
        suffixIcon: IconButton(
          tooltip: 'Rechercher',
          onPressed: () => onSearch(controller.text),
          icon: Icon(Icons.arrow_forward_rounded, color: colors.primary),
        ),
        border: pill(colors.lineSoft, 1),
        enabledBorder: pill(colors.lineSoft, 1),
        focusedBorder: pill(colors.primary, 2),
      ),
    );
  }
}

class _WeeklyListCard extends StatelessWidget {
  const _WeeklyListCard({
    required this.list,
    required this.onOpen,
    required this.onStart,
  });

  final AsyncValue<_WeeklyList?> list;
  final VoidCallback onOpen;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return list.when(
      loading: () => const ListSummary.loading(),
      // The list is a convenience: without it the card invites to start one.
      error: (error, stackTrace) => ListSummary(count: 0, onStart: onStart),
      data: (data) => data == null || data.count == 0
          ? ListSummary(count: 0, onStart: onStart)
          : ListSummary(
              count: data.count,
              best: data.best,
              save: data.save,
              onOpen: onOpen,
            ),
    );
  }
}

/// "Prix du jour": the best known price of the latest products, on the slate.
class _PriceSlate extends StatelessWidget {
  const _PriceSlate({
    required this.products,
    required this.onRetry,
    required this.onOpen,
  });

  final AsyncValue<RepositoryResult<CatalogProductPage>> products;
  final VoidCallback onRetry;
  final ValueChanged<CatalogProduct> onOpen;

  @override
  Widget build(BuildContext context) {
    return products.when(
      loading: () =>
          const MarketSlate(title: 'Prix du jour', rows: [], loading: true),
      error: (error, stackTrace) => MarketSlate(
        title: 'Prix du jour',
        rows: const [],
        error: true,
        onRetry: onRetry,
      ),
      data: (result) {
        final priced = <(CatalogProduct, num)>[
          for (final product in result.value.results)
            // The slate is in FCFA: another currency would be misread.
            if (_priceOf(product) case final price?) (product, price),
        ];
        final updated = priced
            .map((entry) => entry.$1.priceSnapshotUpdatedAt)
            .whereType<DateTime>()
            .fold<DateTime?>(
              null,
              (latest, moment) =>
                  latest == null || moment.isAfter(latest) ? moment : latest,
            );
        return MarketSlate(
          title: 'Prix du jour',
          meta: 'le meilleur prix connu',
          rows: [
            for (final (product, price) in priced)
              SlateRow(
                label: product.name,
                value: price,
                onTap: () => onOpen(product),
              ),
          ],
          footer: updated == null
              ? 'En FCFA'
              : 'En FCFA · mis à jour ${formatAge(updated)}',
        );
      },
    );
  }

  static num? _priceOf(CatalogProduct product) {
    final currency = product.priceSnapshotCurrency;
    if (currency != null && currency.isNotEmpty && currency != 'XAF') {
      return null;
    }
    final amount = num.tryParse((product.priceSnapshot ?? '').trim());
    // The slate shows whole francs. The design's formatter would round a price
    // with decimals (1234.50 -> 1 235): a different amount from the product
    // page, so such a price stays off the slate rather than be shown rounded.
    if (amount == null || amount != amount.truncate()) {
      return null;
    }
    return amount;
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
