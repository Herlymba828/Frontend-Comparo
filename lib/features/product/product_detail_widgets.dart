import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cache_status_banner.dart';
import '../../core/widgets/market_widgets.dart';
import '../availability/models/merchant_availability.dart';
import '../catalog/data/catalog_providers.dart';
import '../catalog/models/catalog_product.dart';
import 'product_helpers.dart';

class ProductHero extends StatelessWidget {
  const ProductHero({super.key, required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final currency = product.priceSnapshotCurrency;
    final price = product.priceSnapshot;

    final hasPrice = price != null && price.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketSurface(
          radius: 18,
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: ProductArtwork(
              url: product.imageUrl,
              name: product.name,
              unitSize: 140,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(product.name, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (product.category != null)
              Chip(label: Text(product.category!.name)),
            if (product.brand != null) Chip(label: Text(product.brand!.name)),
            if (product.isVerified) const Chip(label: Text('Produit vérifié')),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Flexible(
              child: PriceTag(
                label: formatPrice(price, currency),
                style: AppTextStyles.pricePrimary.copyWith(fontSize: 30),
                muted: !hasPrice,
              ),
            ),
            if (hasPrice) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'meilleur prix connu',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class AvailabilitySection extends ConsumerWidget {
  const AvailabilitySection({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(productAvailabilityProvider(productId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Disponibilité chez les marchands',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        availability.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Row(
            children: [
              Expanded(
                child: Text(
                  error is ApiException
                      ? error.userMessage
                      : 'Disponibilité indisponible pour le moment.',
                ),
              ),
              IconButton(
                tooltip: 'Réessayer la disponibilité',
                onPressed: () =>
                    ref.invalidate(productAvailabilityProvider(productId)),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          data: (result) {
            final records = result.value.results;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CacheStatusBanner(result: result),
                if (result.isFromCache) const SizedBox(height: 8),
                if (records.isEmpty)
                  const Text('Aucune disponibilité relevée pour ce produit.')
                else
                  for (final record in records)
                    _AvailabilityRow(availability: record),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({required this.availability});

  final MerchantAvailability availability;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (availability.status) {
      'available' => ('Disponible', AppColors.primary),
      'limited' => ('Stock limité', AppColors.warning),
      'unavailable' => ('Indisponible', AppColors.terracotta),
      'discontinued' => ('Produit arrêté', AppColors.textSecondary),
      _ => ('Disponibilité inconnue', AppColors.info),
    };
    final quantity = nonEmptyProductValue(availability.quantityAvailable);
    final observedAt = availability.observedAt ?? availability.updatedAt;
    final details = [
      if (quantity != null) 'Quantité : ${formatQuantity(quantity)}',
      if (observedAt != null) 'Relevé le ${_formatDay(observedAt)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  availability.merchantName ?? 'Marchand inconnu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (details.isNotEmpty)
                  Text(details, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: StampBadge(label: label, color: color),
          ),
        ],
      ),
    );
  }

  String _formatDay(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class ProductDetails extends StatelessWidget {
  const ProductDetails({super.key, required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Détails du produit',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _InfoRow(label: 'État', value: product.isActive ? 'Actif' : 'Inactif'),
        _InfoRow(
          label: 'Vérification du produit',
          value: product.isVerified ? 'Vérifié' : 'Non confirmée',
        ),
        if (product.priceSnapshotUpdatedAt != null) ...[
          _InfoRow(
            label: 'Mise à jour du prix catalogue',
            value: _formatDate(product.priceSnapshotUpdatedAt!),
          ),
        ],
        if (product.description != null && product.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            product.description!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label : ',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class ProductLoadError extends StatelessWidget {
  const ProductLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

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

class NoOffers extends StatelessWidget {
  const NoOffers({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text('Aucune offre comparable pour ce produit.')),
    );
  }
}

class OfferPagination extends StatelessWidget {
  const OfferPagination({
    super.key,
    required this.currentPage,
    required this.count,
    required this.pageSize,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int count;
  final int pageSize;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final pageCount = count == 0 ? 0 : (count / pageSize).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: hasPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Précédent'),
        ),
        Text('Page $currentPage sur $pageCount'),
        TextButton.icon(
          onPressed: hasNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Suivant'),
        ),
      ],
    );
  }
}
