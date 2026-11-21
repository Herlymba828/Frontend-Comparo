import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cache_status_banner.dart';
import '../../core/voice/voice_service.dart';
import '../alerts/create_price_alert_dialog.dart';
import '../catalog/data/catalog_providers.dart';
import '../catalog/models/catalog_product.dart';
import '../comparison/alternatives.dart';
import '../comparison/models/comparison_offer.dart';
import '../favorites/favorite_buttons.dart';
import '../identity/data/auth_providers.dart';
import '../recommendations/recommendations.dart';
import '../stores/stores_screen.dart';
import 'price_evolution.dart';
import 'product_share.dart';
import 'product_detail_widgets.dart';
import 'product_helpers.dart';
import 'product_offer_widgets.dart';

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
          FavoriteProductButton(productId: id),
          NearbyStoresButton(productId: id),
          if (productAsync.value?.value case final product?)
            IconButton(
              tooltip: 'Écouter',
              onPressed: () => ref
                  .read(voiceServiceProvider)
                  .speak(
                    productSpeech(
                      product.name,
                      product.priceSnapshot == null
                          ? null
                          : formatPrice(
                              product.priceSnapshot,
                              product.priceSnapshotCurrency,
                            ),
                    ),
                  ),
              icon: const Icon(Icons.volume_up_outlined),
            ),
          if (productAsync.value?.value case final product?)
            IconButton(
              tooltip: 'Partager',
              onPressed: () => shareProduct(product),
              icon: const Icon(Icons.share_outlined),
            ),
          IconButton(
            tooltip: 'Mes alertes',
            onPressed: () => context.push('/alerts'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
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
              error: (error, stackTrace) => ProductLoadError(
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
                  ProductHero(product: productResult.value),
                  const SizedBox(height: AppSpacing.space12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push(
                            '/product/${productResult.value.id}/stores'
                            '?name=${Uri.encodeComponent(productResult.value.name)}',
                          ),
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text(
                            'Où acheter',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _startPriceAlert(productResult.value),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text(
                            'Suivre le prix',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
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
                    error: (error, stackTrace) => ProductLoadError(
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
                              nonEmptyProductValue(
                                offer.comparisonGroup?.currency,
                              ) ??
                              nonEmptyProductValue(offer.currency),
                          unitCode:
                              nonEmptyProductValue(
                                offer.comparisonGroup?.unitCode,
                              ) ??
                              nonEmptyProductValue(offer.unitCode),
                        );
                        groups.putIfAbsent(group, () => []).add(offer);
                      }
                      return page.results.isEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CacheStatusBanner(result: pageResult),
                                const NoOffers(),
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
                                        productGroupHeading(
                                          group.key.currency,
                                          group.value,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                  for (final offer in group.value)
                                    OfferCard(
                                      offer: offer,
                                      isBest: offer.isBestOffer,
                                    ),
                                ],
                                if (page.next != null || page.previous != null)
                                  OfferPagination(
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
                  SubstituteRecommendationsSection(productId: id),
                  AlternativesSection(productId: id),
                  PriceEvolutionSection(productId: id),
                  const SizedBox(height: AppSpacing.space24),
                  AvailabilitySection(productId: id),
                  const SizedBox(height: AppSpacing.space24),
                  ProductDetails(product: productResult.value),
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
