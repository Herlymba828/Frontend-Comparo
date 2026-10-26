import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cache_status_banner.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/market_widgets.dart';
import '../alerts/create_price_alert_dialog.dart';
import '../availability/models/merchant_availability.dart';
import '../catalog/data/catalog_providers.dart';
import '../catalog/models/catalog_product.dart';
import '../comparison/models/comparison_offer.dart';
import '../identity/data/auth_providers.dart';

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  int _offersPage = 1;

  @override
  void didUpdateWidget(covariant ProductScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _offersPage = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productId = widget.productId;
    final id = int.tryParse(productId);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Produit')),
        body: const Center(child: Text('Identifiant de produit invalide.')),
      );
    }

    final productAsync = ref.watch(productDetailsProvider(id));
    final comparisonAsync = ref.watch(
      comparisonOffersProvider((
        productId: id,
        location: null,
        page: _offersPage,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche produit'),
        actions: [
          IconButton(
            tooltip: 'Mes alertes',
            onPressed: () => context.push('/alerts'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 1),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productDetailsProvider(id));
              ref.invalidate(productAvailabilityProvider(id));
              ref.invalidate(
                comparisonOffersProvider((
                  productId: id,
                  location: null,
                  page: _offersPage,
                )),
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
                    comparisonOffersProvider((
                      productId: id,
                      location: null,
                      page: _offersPage,
                    )),
                  );
                },
              ),
              data: (productResult) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CacheStatusBanner(result: productResult),
                  if (productResult.isFromCache) const SizedBox(height: 12),
                  _ProductHero(product: productResult.value),
                  const SizedBox(height: AppSpacing.space12),
                  OutlinedButton.icon(
                    onPressed: () => _startPriceAlert(productResult.value),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Suivre le prix'),
                  ),
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
                        comparisonOffersProvider((
                          productId: id,
                          location: null,
                          page: _offersPage,
                        )),
                      ),
                    ),
                    data: (pageResult) {
                      final page = pageResult.value;
                      final groups =
                          <
                            ({String? currency, String? unitCode}),
                            List<ComparisonOffer>
                          >{};
                      for (final offer in page.results) {
                        final group = (
                          currency:
                              _nonEmpty(offer.comparisonGroup?.currency) ??
                              _nonEmpty(offer.currency),
                          unitCode:
                              _nonEmpty(offer.comparisonGroup?.unitCode) ??
                              _nonEmpty(offer.unitCode),
                        );
                        groups.putIfAbsent(group, () => []).add(offer);
                      }
                      return page.results.isEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CacheStatusBanner(result: pageResult),
                                const _NoOffers(),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CacheStatusBanner(result: pageResult),
                                if (pageResult.isFromCache)
                                  const SizedBox(height: 12),
                                for (final group in groups.entries) ...[
                                  if (group.key.currency != null ||
                                      group.key.unitCode != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 8,
                                      ),
                                      child: Text(
                                        _groupHeading(
                                          group.key.currency,
                                          group.value,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                  for (final offer in group.value)
                                    _OfferCard(
                                      offer: offer,
                                      isBest: identical(
                                        offer,
                                        _bestVerifiedOffer(group.value),
                                      ),
                                    ),
                                ],
                                if (page.next != null || page.previous != null)
                                  _OfferPagination(
                                    currentPage: _offersPage,
                                    count: page.count,
                                    pageSize: 20,
                                    hasPrevious: page.previous != null,
                                    hasNext: page.next != null,
                                    onPrevious: () =>
                                        setState(() => _offersPage -= 1),
                                    onNext: () =>
                                        setState(() => _offersPage += 1),
                                  ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: AppSpacing.space24),
                  _AvailabilitySection(productId: id),
                  const SizedBox(height: AppSpacing.space24),
                  _ProductDetails(product: productResult.value),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startPriceAlert(CatalogProduct product) async {
    try {
      var user = await ref.read(authSessionProvider.future);
      if (!mounted) {
        return;
      }
      if (user == null) {
        await context.push('/auth');
        if (!mounted) {
          return;
        }
        user = await ref.read(authSessionProvider.future);
      }
      if (user == null || !mounted) {
        return;
      }
      final created = await showDialog<bool>(
        context: context,
        builder: (context) => CreatePriceAlertDialog(product: product),
      );
      if (created == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre alerte de prix est créée.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.userMessage
            : 'Impossible de démarrer le suivi du prix.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }
}

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.product});

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
            child: ProductArtwork(url: product.imageUrl, unitSize: 140),
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
                child: Transform.rotate(
                  angle: 0.05,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_back,
                        size: 16,
                        color: AppColors.terracotta,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          'prix de\nréférence',
                          style: AppTextStyles.handNote.copyWith(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AvailabilitySection extends ConsumerWidget {
  const _AvailabilitySection({required this.productId});

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
    final quantity = _nonEmpty(availability.quantityAvailable);
    final observedAt = availability.observedAt ?? availability.updatedAt;
    final details = [
      if (quantity != null) 'Quantité : $quantity',
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

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({required this.product});

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
        _InfoRow(
          label: 'Disponibilité',
          value: _availabilityLabel(product.availability),
        ),
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

  String _availabilityLabel(String value) => switch (value) {
    'available' => 'Disponible',
    'unavailable' => 'Indisponible',
    'unknown' => 'Disponibilité inconnue',
    _ => value,
  };

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
      child: Center(child: Text('Aucune offre comparable pour ce produit.')),
    );
  }
}

class _OfferPagination extends StatelessWidget {
  const _OfferPagination({
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

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, this.isBest = false});

  final ComparisonOffer offer;

  /// Offre vérifiée la moins chère de son groupe de comparaison.
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final normalized = offer.normalizedUnitPrice;
    final normalizedUnit =
        _nonEmpty(offer.normalizedUnit?.symbol) ??
        _nonEmpty(offer.normalizedUnit?.code) ??
        _nonEmpty(offer.unitSymbol) ??
        _nonEmpty(offer.unitCode);
    final normalizedLabel = normalized == null || normalized.isEmpty
        ? null
        : [
            formatUnitPrice(normalized, offer.currency),
            if (normalizedUnit != null) '/ $normalizedUnit',
          ].join(' ');

    final source = _nonEmpty(offer.sourceLabel) ?? 'Source inconnue';
    final freshness = _freshnessLabel(offer.freshness);
    final observedAt = offer.observedAt != null
        ? _formatDateTime(offer.observedAt!)
        : 'Date inconnue';
    final verification = _verificationLabel(offer.verificationLevel);
    final availability = _availabilityLabel(offer.availability);
    final location = _nonEmpty(offer.location);
    final unit = _nonEmpty(offer.unitSymbol ?? offer.unitCode);
    final quantity = [formatQuantity(offer.quantity), ?unit].join(' ');

    final comparable = offer.isActive && offer.isCurrentlyValid;
    final card = MarketSurface(
      muted: !comparable,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.terracotta,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    StampBadge(
                      label: offer.isCurrentlyValid
                          ? 'Offre valide'
                          : 'Hors période',
                      color: offer.isCurrentlyValid
                          ? AppColors.primary
                          : AppColors.terracotta,
                      angle: -1.5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: PriceTag(
                  label: formatPrice(offer.amount, offer.currency),
                  style: AppTextStyles.pricePrimary.copyWith(fontSize: 26),
                  caption: quantity.isEmpty ? null : quantity,
                  muted: !comparable,
                  angle: comparable ? -1.5 : 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(
                icon: availability == 'Disponible'
                    ? Icons.inventory_2_outlined
                    : Icons.info_outline,
                label: 'Disponibilité : $availability',
              ),
              _Badge(icon: Icons.schedule, label: 'Fraîcheur : $freshness'),
              _Badge(icon: Icons.update, label: 'Observé : $observedAt'),
              _Badge(icon: Icons.source, label: 'Source : $source'),
              _Badge(
                icon: Icons.verified_outlined,
                label: 'Prix : $verification',
              ),
              _Badge(
                icon: offer.isActive ? Icons.check_circle : Icons.block,
                label: offer.isActive ? 'Actif' : 'Inactif',
                color: offer.isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ],
          ),
          if (normalizedLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              'Prix unitaire : $normalizedLabel',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
            ),
          ],
          if (offer.promotionLabel != null &&
              offer.promotionLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              offer.promotionLabel!.trim(),
              style: AppTextStyles.handNote.copyWith(fontSize: 18),
            ),
          ],
          if (offer.comparisonReasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: offer.comparisonReasons
                  .map(
                    (reason) => _Badge(
                      icon: Icons.compare_arrows,
                      label: _reasonLabel(reason),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    if (!isBest) {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: card);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          const Positioned(top: -40, right: -8, child: BestPriceSeal()),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Offre au plus bas prix unitaire normalisé parmi les offres d'un même
/// `comparison_group` (même devise et même unité de base) qui sont vérifiées,
/// actives, valides, récentes et non promotionnelles ; `null` si moins de deux
/// offres sont ainsi comparables. Les promotions sont exclues car leurs
/// conditions d'éligibilité ne sont pas validées (contrat P0.4). Le lieu reste
/// affiché sur chaque offre.
ComparisonOffer? _bestVerifiedOffer(List<ComparisonOffer> offers) {
  ComparisonOffer? best;
  double? bestUnitPrice;
  var eligible = 0;
  for (final offer in offers) {
    final level = offer.verificationLevel?.toLowerCase();
    final freshness = offer.freshness?.toLowerCase();
    final unitPrice = double.tryParse(
      (offer.normalizedUnitPrice ?? '').trim().replaceAll(',', '.'),
    );
    if (!offer.isActive ||
        !offer.isCurrentlyValid ||
        offer.isPromotion ||
        offer.comparisonGroup == null ||
        unitPrice == null ||
        !_verifiedLevels.contains(level) ||
        !_recentFreshness.contains(freshness)) {
      continue;
    }
    eligible++;
    if (bestUnitPrice == null || unitPrice < bestUnitPrice) {
      best = offer;
      bestUnitPrice = unitPrice;
    }
  }
  return eligible >= 2 ? best : null;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// En-tête d'un groupe d'offres : unité lisible (symbole plutôt que code
/// technique) et mention explicite quand le backend n'a pas pu normaliser.
String _groupHeading(String? currency, List<ComparisonOffer> offers) {
  final sample = offers.first;
  final unit =
      _nonEmpty(sample.normalizedUnit?.symbol) ??
      _nonEmpty(sample.unitSymbol) ??
      _nonEmpty(sample.comparisonGroup?.unitCode) ??
      _nonEmpty(sample.unitCode);
  final label = [?currency, ?unit].join(' / ');
  final comparable = offers.any((offer) => offer.comparisonGroup != null);
  return comparable
      ? 'Prix comparés en $label'
      : 'Sans prix unitaire comparable ($label)';
}

/// Valeurs de `Price.VerificationLevel` qui attestent une vérification
/// (`backend/apps/pricing/models.py`).
const _verifiedLevels = {'auto', 'manual', 'official'};

/// Valeurs de `Price.Freshness` considérées comme récentes.
const _recentFreshness = {'very_recent', 'recent'};

// Libellés alignés sur les choix Django (`Price.Freshness`,
// `Price.VerificationLevel`, `Price.Availability`).
String _freshnessLabel(String? value) => switch (value?.toLowerCase()) {
  'very_recent' => 'Très récente',
  'recent' => 'Récente',
  'old' => 'Ancienne',
  'expire' => 'Expirée',
  'unknown' => 'Inconnue',
  null || '' => 'Non renseignée',
  _ => value!.replaceAll('_', ' '),
};

String _verificationLabel(String? value) => switch (value?.toLowerCase()) {
  'none' => 'Non vérifié',
  'auto' => 'Vérifié automatiquement',
  'manual' => 'Vérifié manuellement',
  'official' => 'Source officielle',
  null || '' => 'Non renseignée',
  _ => value!.replaceAll('_', ' '),
};

String _availabilityLabel(String? value) => switch (value?.toLowerCase()) {
  'available' => 'Disponible',
  'limited' => 'Stock limité',
  'unavailable' => 'Indisponible',
  'unknown' || null || '' => 'Inconnue',
  _ => value!.replaceAll('_', ' '),
};

String _reasonLabel(String value) {
  final normalized = value.toLowerCase();
  return switch (normalized) {
    'same_product' => 'Même produit',
    'strict_equivalence' => 'Équivalence vérifiée',
    'same_unit' => 'Même unité',
    'same_currency' => 'Même devise',
    'no_exact_conversion_to_base_unit' =>
      'Prix unitaire indisponible : pas de conversion exacte',
    'ambiguous_base_unit_for_unit_type' =>
      'Prix unitaire indisponible : unité de base ambiguë',
    'no_base_unit_for_unit_type' =>
      'Prix unitaire indisponible : aucune unité de base',
    'invalid_conversion_factor' =>
      'Prix unitaire indisponible : conversion invalide',
    'non_positive_quantity' =>
      'Prix unitaire indisponible : quantité non valide',
    _ => value.replaceAll('_', ' '),
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? AppColors.ink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.ink, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
