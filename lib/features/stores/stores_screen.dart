import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import 'stores_repository.dart';

/// Map-pin button opening the stores that sell a product.
class NearbyStoresButton extends StatelessWidget {
  const NearbyStoresButton({
    super.key,
    required this.productId,
    this.productName,
    this.compact = false,
  });

  final int productId;
  final String? productName;

  /// Small round button for product cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void open() => context.push(
      '/product/$productId/stores'
      '${productName == null ? '' : '?name=${Uri.encodeComponent(productName!)}'}',
    );
    if (compact) {
      return Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.ink)),
        child: IconButton(
          tooltip: 'Magasins proches qui vendent ce produit',
          icon: const Icon(
            Icons.location_on_outlined,
            color: AppColors.terracotta,
          ),
          onPressed: open,
        ),
      );
    }
    return IconButton(
      tooltip: 'Magasins proches qui vendent ce produit',
      icon: const Icon(Icons.location_on_outlined),
      onPressed: open,
    );
  }
}

/// Stores selling a product: price, availability, distance, directions.
class StoresScreen extends ConsumerStatefulWidget {
  const StoresScreen({super.key, required this.productId, this.productName});

  final int productId;
  final String? productName;

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  String? _ordering;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(userPositionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productName ?? 'Magasins'),
        actions: [
          IconButton(
            tooltip: 'Actualiser ma position',
            icon: const Icon(Icons.my_location),
            onPressed: () => ref.invalidate(userPositionProvider),
          ),
        ],
      ),
      body: position.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.space12),
              Text('Recherche de votre position…'),
            ],
          ),
        ),
        error: (error, stackTrace) => _stores(
          const UserPosition.missing(
            'Position introuvable : magasins triés par prix.',
          ),
        ),
        data: _stores,
      ),
    );
  }

  Widget _stores(UserPosition position) {
    final ordering = _ordering ?? (position.isKnown ? 'distance' : 'price');
    final query = (
      productId: widget.productId,
      lat: position.latitude,
      lon: position.longitude,
      ordering: ordering,
    );
    final stores = ref.watch(productStoresProvider(query));
    return Column(
      children: [
        if (!position.isKnown)
          MaterialBanner(
            leading: const Icon(Icons.location_off_outlined),
            content: Text(position.problem ?? ''),
            actions: [
              TextButton(
                onPressed: () => ref.invalidate(userPositionProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space12,
            AppSpacing.space16,
            0,
          ),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'distance',
                enabled: position.isKnown,
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('Plus proches'),
              ),
              const ButtonSegment(
                value: 'price',
                icon: Icon(Icons.sell_outlined),
                label: Text('Moins chers'),
              ),
            ],
            selected: {ordering},
            onSelectionChanged: (value) =>
                setState(() => _ordering = value.first),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(productStoresProvider(query)),
            child: AsyncBody<List<ProductStore>>(
              value: stores,
              onRetry: () => ref.invalidate(productStoresProvider(query)),
              errorFallback: 'Impossible de charger les magasins.',
              builder: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.store_mall_directory_outlined,
                      title: 'Aucun magasin ne vend ce produit pour le moment.',
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.space16),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.space8),
                      itemBuilder: (context, index) => _StoreCard(
                        store: items[index],
                        isCheapest: ordering == 'price' && index == 0,
                        isClosest: ordering == 'distance' && index == 0,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.isCheapest,
    required this.isClosest,
  });

  final ProductStore store;
  final bool isCheapest;
  final bool isClosest;

  String get _distance {
    final km = store.distanceKm;
    if (km == null) {
      return 'Distance inconnue';
    }
    return km < 1
        ? '${(km * 1000).round()} m'
        : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showInfo(context, 'Aucune application ne peut ouvrir ce lien.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = store.unitSymbol.isEmpty ? '' : ' ${store.unitSymbol}';
    return MarketSurface(
      padding: const EdgeInsets.all(AppSpacing.space12),
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
                      store.merchantName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(store.locationName),
                    if (store.address.isNotEmpty)
                      Text(
                        store.address,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              PriceTag(
                label: formatPrice(store.amount, store.currency),
                style: AppTextStyles.pricePrimary.copyWith(fontSize: 24),
                caption: '${formatQuantity(store.quantity)}$unit',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space8),
          Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: const Icon(Icons.near_me_outlined, size: 16),
                label: Text(_distance),
              ),
              StatusStamp(store.availability),
              if (store.unitPrice != null)
                Text(
                  '${formatUnitPrice(store.unitPrice, store.currency)}'
                  ' / ${store.unitPriceUnit ?? 'unité'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (isCheapest)
                const StampBadge(
                  label: 'LE MOINS CHER',
                  color: AppColors.terracotta,
                ),
              if (isClosest)
                const StampBadge(
                  label: 'LE PLUS PROCHE',
                  color: AppColors.primary,
                ),
              if (store.isPromotion)
                const StampBadge(label: 'PROMO', color: AppColors.terracotta),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (store.phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () =>
                      _open(context, Uri(scheme: 'tel', path: store.phone)),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Appeler'),
                ),
              if (store.hasCoordinates || store.address.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _open(
                    context,
                    Uri.https('www.google.com', '/maps/dir/', {
                      'api': '1',
                      'destination': store.hasCoordinates
                          ? '${store.latitude},${store.longitude}'
                          : '${store.locationName}, ${store.address}',
                    }),
                  ),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Itinéraire'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
