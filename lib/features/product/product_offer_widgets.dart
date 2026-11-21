import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/market_widgets.dart';
import '../commerce/commerce_repository.dart';
import '../comparison/models/comparison_offer.dart';
import '../comparison/trust_line.dart';
import '../favorites/favorite_buttons.dart';
import '../identity/data/auth_providers.dart';
import '../quality/price_flag.dart';
import 'product_helpers.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer, this.isBest = false});

  final ComparisonOffer offer;

  /// Offre vérifiée la moins chère de son groupe de comparaison.
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final normalized = offer.normalizedUnitPrice;
    final normalizedUnit =
        nonEmptyProductValue(offer.normalizedUnit?.symbol) ??
        nonEmptyProductValue(offer.normalizedUnit?.code) ??
        nonEmptyProductValue(offer.unitSymbol) ??
        nonEmptyProductValue(offer.unitCode);
    final normalizedLabel = normalized == null || normalized.isEmpty
        ? null
        : [
            formatUnitPrice(normalized, offer.currency),
            if (normalizedUnit != null) '/ $normalizedUnit',
          ].join(' ');

    final source = readableSource(offer.sourceLabel) ?? 'Source inconnue';
    final freshness = _freshnessLabel(offer.freshness);
    final observedAt = offer.observedAt != null
        ? _formatDateTime(offer.observedAt!)
        : 'Date inconnue';
    final verification = _verificationLabel(offer.verificationLevel);
    final availability = _availabilityLabel(offer.availability);
    final location = nonEmptyProductValue(offer.location);
    final unit = nonEmptyProductValue(offer.unitSymbol ?? offer.unitCode);
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
              // The API's trust line replaces freshness and verification.
              if (offer.trust == null) ...[
                _Badge(icon: Icons.schedule, label: 'Fraîcheur : $freshness'),
                _Badge(icon: Icons.update, label: 'Observé : $observedAt'),
              ],
              _Badge(icon: Icons.source, label: 'Source : $source'),
              if (offer.trust == null)
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
          if (offer.trust case final trust?) ...[
            const SizedBox(height: 8),
            TrustLine(trust: trust),
          ],
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
          if (comparable) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                _FlagPriceButton(offer: offer),
                if (offer.merchant case final merchantId?)
                  FavoriteShopButton(merchantId: merchantId),
                _AddToCartButton(offer: offer),
              ],
            ),
          ],
        ],
      ),
    );

    if (!isBest) {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: card);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          const Positioned(top: -16, right: 12, child: BestPriceSeal()),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

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

/// Adds one unit of this offer to the cart (sign-in required).
/// "Signaler ce prix": tells the moderators a shown price looks wrong.
class _FlagPriceButton extends ConsumerWidget {
  const _FlagPriceButton({required this.offer});

  final ComparisonOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () => showPriceFlagSheet(
        context,
        ref,
        offerId: offer.id,
        merchantName: offer.merchantName ?? 'ce commerce',
      ),
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Signaler ce prix'),
    );
  }
}

class _AddToCartButton extends ConsumerStatefulWidget {
  const _AddToCartButton({required this.offer});

  final ComparisonOffer offer;

  @override
  ConsumerState<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends ConsumerState<_AddToCartButton> {
  bool _adding = false;

  Future<void> _add() async {
    final user = await ref.read(authSessionProvider.future);
    if (!mounted) {
      return;
    }
    if (user == null) {
      context.push('/auth');
      return;
    }
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(commerceRepositoryProvider)
          .addToCart(
            productId: widget.offer.product,
            quantity: '1',
            offerId: widget.offer.id,
          );
      ref.invalidate(cartProvider);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Ajouté au panier.'),
          action: SnackBarAction(
            label: 'Voir le panier',
            onPressed: () => router.push('/cart'),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.userMessage
                : 'Impossible d’ajouter cette offre au panier.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _adding ? null : _add,
      icon: const Icon(Icons.add_shopping_cart),
      label: const Text('Ajouter au panier'),
    );
  }
}
