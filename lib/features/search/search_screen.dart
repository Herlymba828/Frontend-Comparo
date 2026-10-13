import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../catalog/data/catalog_providers.dart';
import '../catalog/models/catalog_product.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _controller.text = widget.initialQuery;
      _query = widget.initialQuery.trim();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch(String value) {
    FocusScope.of(context).unfocus();
    setState(() => _query = value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final results = _query.isEmpty ? null : ref.watch(searchProductsProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Recherche')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          Expanded(
            child: results == null
                ? const _SearchPrompt()
                : results.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => _SearchError(
                      message: error is ApiException
                          ? error.userMessage
                          : 'Une erreur inattendue est survenue.',
                      onRetry: () =>
                          ref.invalidate(searchProductsProvider(_query)),
                    ),
                    data: (page) => page.results.isEmpty
                        ? const _EmptyResults()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: page.results.length,
                            itemBuilder: (context, index) => _ProductTile(
                              product: page.results[index],
                              onTap: () => context.push(
                                '/product/${page.results[index].id}',
                              ),
                            ),
                          ),
                  ),
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
        padding: EdgeInsets.all(24),
        child: Text('Saisissez le nom d’un produit pour lancer la recherche.'),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
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

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: _ProductImage(url: product.imageUrl),
        title: Text(product.name),
        subtitle: Text(
          [
            if (product.brand case final brand?) brand.name,
            if (product.category case final category?) category.name,
            _availabilityLabel(product.availability),
            if (product.isVerified) 'Vérifié',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 100,
          child: Text(
            price == null || currency == null
                ? 'Prix non renseigné'
                : '$price $currency',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          ),
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.shopping_bag_outlined));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const CircleAvatar(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
