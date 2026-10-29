import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/storage/repository_result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/cache_status_banner.dart';
import '../../core/widgets/market_widgets.dart';
import '../catalog/data/catalog_providers.dart';
import '../catalog/models/catalog_product.dart';
import '../catalog/models/catalog_product_page.dart';
import '../catalog/models/catalog_search_request.dart';
import '../stores/stores_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = '', this.initialCategory});

  final String initialQuery;
  final String? initialCategory;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late String _query;
  int _page = 1;
  String? _category;
  String? _ordering;
  bool _availableOnly = false;
  bool _verifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _category = widget.initialCategory;
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialCategory != widget.initialCategory) {
      _controller.text = widget.initialQuery;
      _query = widget.initialQuery.trim();
      _category = widget.initialCategory;
      _page = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch(String value) {
    FocusScope.of(context).unfocus();
    setState(() {
      _query = value.trim();
      _page = 1;
    });
  }

  void _loadPage(int page) {
    if (_query.isEmpty && _category == null) {
      return;
    }
    setState(() => _page = page);
  }

  void _updateFilters({
    String? category,
    String? ordering,
    bool? availableOnly,
    bool? verifiedOnly,
  }) {
    setState(() {
      if (category != null) {
        _category = category.isEmpty ? null : category;
      }
      if (ordering != null) {
        _ordering = ordering.isEmpty ? null : ordering;
      }
      if (availableOnly != null) {
        _availableOnly = availableOnly;
      }
      if (verifiedOnly != null) {
        _verifiedOnly = verifiedOnly;
      }
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryTreeProvider);
    final request = CatalogSearchRequest(
      query: _query,
      category: _category,
      available: _availableOnly,
      verified: _verifiedOnly,
      ordering: _ordering,
      page: _page,
      pageSize: 20,
    );
    final results = _query.isEmpty && _category == null
        ? null
        : ref.watch(searchProductsProvider(request));

    return Scaffold(
      appBar: AppBar(title: const Text('Recherche de produit')),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 1),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space12,
              AppSpacing.space16,
              AppSpacing.space8,
            ),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _submitSearch,
              decoration: InputDecoration(
                labelText: 'Produit',
                hintText: 'Ex : iPhone, lait, aspirateur',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Rechercher',
                  onPressed: () => _submitSearch(_controller.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              0,
              AppSpacing.space16,
              AppSpacing.space8,
            ),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final categoryField = categories.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => TextButton.icon(
                        onPressed: () => ref.invalidate(categoryTreeProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Catégories indisponibles'),
                      ),
                      data: (tree) => DropdownButtonFormField<String>(
                        initialValue: _category ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text(
                              'Toutes les catégories',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final category in _flattenCategories(tree))
                            DropdownMenuItem(
                              value: category.slug,
                              child: Text(
                                category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            _updateFilters(category: value ?? ''),
                      ),
                    );
                    final orderingField = DropdownButtonFormField<String>(
                      initialValue: _ordering ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Trier par',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Pertinence')),
                        DropdownMenuItem(value: 'name', child: Text('Nom')),
                        DropdownMenuItem(
                          value: 'price_snapshot',
                          child: Text('Prix croissant'),
                        ),
                        DropdownMenuItem(
                          value: '-price_snapshot',
                          child: Text('Prix décroissant'),
                        ),
                      ],
                      onChanged: (value) =>
                          _updateFilters(ordering: value ?? ''),
                    );

                    if (constraints.maxWidth < 520) {
                      return Column(
                        children: [
                          categoryField,
                          const SizedBox(height: AppSpacing.space8),
                          orderingField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: categoryField),
                        const SizedBox(width: AppSpacing.space12),
                        Expanded(child: orderingField),
                      ],
                    );
                  },
                ),
                Wrap(
                  spacing: AppSpacing.space8,
                  runSpacing: AppSpacing.space8,
                  children: [
                    FilterChip(
                      label: const Text('Disponible'),
                      selected: _availableOnly,
                      onSelected: (selected) =>
                          _updateFilters(availableOnly: selected),
                    ),
                    FilterChip(
                      label: const Text('Vérifié'),
                      selected: _verifiedOnly,
                      onSelected: (selected) =>
                          _updateFilters(verifiedOnly: selected),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: results == null
                ? const _SearchPrompt()
                : results.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _SearchError(
                      message: error is ApiException
                          ? error.userMessage
                          : 'Une erreur inattendue est survenue.',
                      onRetry: () =>
                          ref.invalidate(searchProductsProvider(request)),
                    ),
                    data: (result) => _SearchResults(
                      result: result,
                      currentPage: _page,
                      onNext: () => _loadPage(_page + 1),
                      onPrevious: () => _loadPage(_page - 1),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Iterable<CatalogCategory> _flattenCategories(
  List<CatalogCategory> categories,
) sync* {
  for (final category in categories) {
    yield category;
    yield* _flattenCategories(category.children);
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.result,
    required this.currentPage,
    required this.onNext,
    required this.onPrevious,
  });

  final RepositoryResult<CatalogProductPage> result;
  final int currentPage;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final page = result.value;
    final uniqueProducts = {
      for (final product in page.results) product.id: product,
    }.values.toList(growable: false);
    final pageCount = page.count == 0 ? 0 : (page.count / 20).ceil();

    return Column(
      children: [
        CacheStatusBanner(result: result),
        if (page.next != null || page.previous != null)
          _SearchPagination(
            currentPage: currentPage,
            pageCount: pageCount,
            hasPrevious: page.previous != null,
            hasNext: page.next != null,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
        Expanded(
          child: uniqueProducts.isEmpty
              ? const _EmptyResults()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: uniqueProducts.length,
                  itemBuilder: (context, index) {
                    final product = uniqueProducts[index];
                    return _ProductTile(
                      product: product,
                      onTap: () => context.push('/product/${product.id}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SearchPagination extends StatelessWidget {
  const _SearchPagination({
    required this.currentPage,
    required this.pageCount,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: hasPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Précédent'),
          ),
          Text(
            pageCount == 0
                ? 'Page $currentPage'
                : 'Page $currentPage sur $pageCount',
            semanticsLabel: 'Page $currentPage sur $pageCount',
          ),
          TextButton.icon(
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Suivant'),
          ),
        ],
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.space24),
        child: Text(
          'Saisissez un produit ou choisissez une catégorie pour lancer la recherche.',
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Aucun produit ne correspond à cette recherche.'),
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.space12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});

  final CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = product.priceSnapshot;
    final currency = product.priceSnapshotCurrency;

    final hasPrice = price != null && price.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space12),
      child: MarketSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.space12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 84,
                height: 84,
                child: ProductArtwork(url: product.imageUrl, unitSize: 84),
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (product.brand != null) ...[
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      product.brand!.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.space8),
                  Row(
                    children: [
                      Flexible(
                        child: PriceTag(
                          label: formatPrice(price, currency),
                          muted: !hasPrice,
                        ),
                      ),
                      const Spacer(),
                      NearbyStoresButton(
                        productId: product.id,
                        productName: product.name,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    [
                      _availabilityLabel(product.availability),
                      if (product.isVerified) 'Vérifié',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  String _availabilityLabel(String value) => switch (value) {
    'available' => 'Disponible',
    'unavailable' => 'Indisponible',
    'unknown' => 'Disponibilité inconnue',
    _ => 'Disponibilité : $value',
  };
}
