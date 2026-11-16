import 'package:comparo_ui/comparo_ui.dart' as comparo;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Carte à plat : fond papier et filet léger, sans ombre (design Comparo v2.4).
class MarketSurface extends StatelessWidget {
  const MarketSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.muted = false,
    this.radius = comparo.ComparoDims.radiusCard,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Offre non comparable ou donnée secondaire : fond grisé.
  final bool muted;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: muted ? AppColors.disabled : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Un prix. Simple chiffre par défaut ; avec [best], l'étiquette citron du
/// design, réservée au meilleur prix d'un produit.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.label,
    this.style = AppTextStyles.priceSecondary,
    this.caption,
    this.muted = false,
    this.best = false,
  });

  final String label;
  final TextStyle style;

  /// Ligne secondaire sous le prix (ex. prix au kilo).
  final String? caption;

  /// Prix inconnu ou offre non comparable : texte gris, jamais en étiquette.
  final bool muted;

  /// Le meilleur prix du produit : étiquette citron.
  final bool best;

  @override
  Widget build(BuildContext context) {
    final price = best && !muted
        ? comparo.PriceTag.text(label, kind: comparo.PriceTagKind.best)
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted
                ? style.copyWith(color: AppColors.textSecondary)
                : style,
          );
    if (caption == null) {
      return price;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        price,
        const SizedBox(height: 3),
        Text(
          caption!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

/// Badge d'état : contour et fond de la couleur, sans inclinaison.
class StampBadge extends StatelessWidget {
  const StampBadge({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(comparo.ComparoDims.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.stamp.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Meilleur prix vérifié » : l'étiquette citron posée sur la meilleure offre.
class BestPriceSeal extends StatelessWidget {
  const BestPriceSeal({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Meilleur prix vérifié',
      excludeSemantics: true,
      child: const comparo.PriceTag.text(
        'Meilleur prix vérifié',
        kind: comparo.PriceTagKind.best,
      ),
    );
  }
}

/// Le picto du design pour un produit, d'après son nom ; « conserve » à défaut.
comparo.PictoKind pictoKindFor(String? name) {
  final text = (name ?? '').toLowerCase();
  const keywords = {
    'riz': comparo.PictoKind.riz,
    'huile': comparo.PictoKind.huile,
    'sucre': comparo.PictoKind.sucre,
    'lait': comparo.PictoKind.lait,
    'sardine': comparo.PictoKind.sardine,
    'eau': comparo.PictoKind.eau,
    'savon': comparo.PictoKind.savon,
  };
  for (final entry in keywords.entries) {
    if (RegExp('\\b${entry.key}').hasMatch(text)) {
      return entry.value;
    }
  }
  return comparo.PictoKind.conserve;
}

/// Image produit : photo de l'API si elle existe, sinon le picto du produit.
class ProductArtwork extends StatelessWidget {
  const ProductArtwork({super.key, this.url, this.name, this.unitSize});

  final String? url;

  /// Nom du produit, pour choisir le picto quand il n'y a pas de photo.
  final String? name;
  final double? unitSize;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.disabled,
      child: Center(
        child: ExcludeSemantics(
          child: comparo.ProductPicto(
            kind: pictoKindFor(name),
            large: (unitSize ?? 0) >= 84,
          ),
        ),
      ),
    );
    final uri = Uri.tryParse(url?.trim() ?? '');
    // Les URL d'images sont fournies par les marchands : HTTPS uniquement.
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return fallback;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Décodage à la taille affichée : une image de plusieurs milliers de
        // pixels ne doit pas être décodée en pleine résolution.
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.hasBoundedWidth
            ? (constraints.maxWidth * ratio).round()
            : null;
        return Image.network(
          uri.toString(),
          fit: BoxFit.cover,
          cacheWidth: width == null || width <= 0 ? null : width,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      },
    );
  }
}
