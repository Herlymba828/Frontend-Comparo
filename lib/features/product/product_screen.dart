import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/theme/app_tokens.dart';
import '../catalog/data/catalog_providers.dart';
import '../catalog/models/catalog_product.dart';
import '../comparison/models/comparison_offer.dart';

class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(productId);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Produit')),
        body: const Center(
          child: Text('Identifiant de produit invalide.'),
        ),
      );
    }

    final productAsync = ref.watch(productDetailsProvider(id));
    final comparisonAsync = ref.watch(
      comparisonOffersProvider((productId: id, location: null)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Fiche produit')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productDetailsProvider(id));
          ref.invalidate(
            comparisonOffersProvider((productId: id, location: null)),
          );
        },
        child: productAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ProductLoadError(
            message: error is ApiException
                ? error.userMessage
                : 'Impossible de charger ce produit.',
            onRetry: () {
              ref.invalidate(productDetailsProvider(id));
              ref.invalidate(
                comparisonOffersProvider((productId: id, location: null)),
              );
            },
          ),
          data: (product) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProductHero(product: product),
              const SizedBox(height: 20),
              Text(
                'Comparaison d’offres',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              comparisonAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => _ProductLoadError(
                  message: error is ApiException
                      ? error.userMessage
                      : 'Impossible de charger les offres.',
                  onRetry: () => ref.invalidate(
                    comparisonOffersProvider((productId: id, location: null)),
                  ),
                ),
                data: (page) => page.results.isEmpty
                    ? const _NoOffers()
                    : Column(
                        children: [
                          for (final offer in page.results)
                            _OfferCard(offer: offer),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final currency = product.priceSnapshotCurrency ?? '€';
    final price = product.priceSnapshot ?? 'Prix non renseigné';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: _ProductImage(url: product.imageUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (product.category != null)
                            Chip(label: Text(product.category!.name)),
                          if (product.brand != null)
                            Chip(label: Text(product.brand!.name)),
                          if (product.isVerified)
                            const Chip(
                              avatar: Icon(Icons.verified_outlined),
                              label: Text('Vérifié'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$price $currency',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Disponibilité', value: _availabilityLabel(product.availability)),
            _InfoRow(
              label: 'État',
              value: product.isActive ? 'Actif' : 'Inactif',
            ),
            if (product.description != null && product.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                product.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _availabilityLabel(String value) => switch (value) {
        'available' => 'Disponible',
        'unavailable' => 'Indisponible',
        'unknown' => 'Disponibilité inconnue',
        _ => value,
      };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label : ', style: Theme.of(context).textTheme.labelLarge),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ProductLoadError extends StatelessWidget {
  const _ProductLoadError({required this.message, required this.onRetry});

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

class _NoOffers extends StatelessWidget {
  const _NoOffers();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text('Aucune offre comparable pour ce produit.'),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final ComparisonOffer offer;

  @override
  Widget build(BuildContext context) {
    final normalized = offer.normalizedUnitPrice;
    final normalizedLabel = normalized == null || normalized.isEmpty
        ? 'Prix de référence non calculable'
        : '$normalized ${offer.currency} / ${offer.normalizedUnit?.code ?? offer.unitCode ?? 'unité'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.merchantName ?? 'Marchand inconnu',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (offer.location != null && offer.location!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(offer.location!),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${offer.amount} ${offer.currency}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Quantité : ${offer.quantity} ${offer.unitSymbol ?? offer.unitCode ?? ''}'.trim(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            _OfferValidity(isValid: offer.isCurrentlyValid),
            if (normalized != null && normalized.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Prix unitaire normalisé : $normalizedLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (offer.promotionLabel != null && offer.promotionLabel!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                offer.promotionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (offer.comparisonReasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: offer.comparisonReasons
                    .map((reason) => Chip(label: Text(reason)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Offer validity: a label and an icon, never colour alone (DOC-FE-UX-001 §5.3).
class _OfferValidity extends StatelessWidget {
  const _OfferValidity({required this.isValid});

  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isValid ? scheme.primary : scheme.error;
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle_outline : Icons.schedule,
          size: AppSize.icon,
          color: color,
        ),
        const SizedBox(width: AppSpace.s2),
        Flexible(
          child: Text(
            isValid ? 'Offre actuellement valide' : 'Offre hors période',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainerHigh;
    if (url == null || url!.isEmpty) {
      return ColoredBox(
        color: placeholder,
        child: const Icon(Icons.shopping_bag_outlined),
      );
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: placeholder,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
