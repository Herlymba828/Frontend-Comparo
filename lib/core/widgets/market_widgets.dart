import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Surface papier à bord encré et ombre imprimée (cartes produit, offres).
class MarketSurface extends StatelessWidget {
  const MarketSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.muted = false,
    this.radius = 14,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Offre non comparable ou donnée secondaire : bord clair, sans ombre.
  final bool muted;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: muted ? AppColors.border : AppColors.ink,
        width: 1.2,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: muted ? null : inkShadow(),
      ),
      child: Material(
        color: AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Étiquette de prix en kraft, perforée et légèrement de travers.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.label,
    this.style = AppTextStyles.priceSecondary,
    this.caption,
    this.muted = false,
    this.angle = -2,
  });

  final String label;
  final TextStyle style;

  /// Ligne secondaire sous le prix (ex. prix au kilo).
  final String? caption;

  /// Prix inconnu ou offre non comparable : papier pointillé, texte gris.
  final bool muted;

  /// Inclinaison en degrés.
  final double angle;

  @override
  Widget build(BuildContext context) {
    final holeSize = style.fontSize! >= 24 ? 9.0 : 7.0;
    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, 5, 12, caption == null ? 4 : 6),
        decoration: BoxDecoration(
          color: muted ? AppColors.disabled : AppColors.kraft,
          border: Border.all(
            color: muted ? AppColors.border : AppColors.kraftEdge,
          ),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(12),
            right: Radius.circular(4),
          ),
          boxShadow: muted
              ? null
              : inkShadow(
                  offset: 2,
                  color: AppColors.kraftEdge.withValues(alpha: 0.6),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: holeSize,
              height: holeSize,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted
                        ? style.copyWith(color: AppColors.textSecondary)
                        : style,
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge façon tampon encreur.
class StampBadge extends StatelessWidget {
  const StampBadge({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.icon,
    this.angle = 0,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(4),
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
      ),
    );
  }
}

/// Tampon rond « Meilleur prix » posé sur la meilleure offre vérifiée.
class BestPriceSeal extends StatelessWidget {
  const BestPriceSeal({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Meilleur prix vérifié',
      excludeSemantics: true,
      child: Transform.rotate(
        angle: -12 * math.pi / 180,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.terracotta,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 2),
            boxShadow: inkShadow(),
          ),
          padding: const EdgeInsets.all(8),
          // Le texte s'ajuste au disque, même avec un grand facteur de texte.
          child: const FittedBox(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MEILLEUR',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    color: AppColors.surface,
                    fontSize: 8,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'PRIX',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    color: AppColors.surface,
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'vérifié',
                  style: TextStyle(
                    fontFamily: AppFonts.hand,
                    color: AppColors.accent,
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Motif wax de marque (vert, lime, terracotta, kraft), répété à l'horizontale.
class WaxPattern extends StatelessWidget {
  const WaxPattern({super.key, this.unitSize});

  /// Côté d'un motif ; par défaut la hauteur disponible.
  final double? unitSize;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(painter: _WaxPainter(unitSize), size: Size.infinite),
    );
  }
}

class _WaxPainter extends CustomPainter {
  _WaxPainter(this.unitSize);

  final double? unitSize;

  static const _palettes = [
    // fond, anneau, cœur, point, coins
    [
      AppColors.primary,
      AppColors.accent,
      AppColors.terracotta,
      AppColors.kraft,
      AppColors.ink,
    ],
    [
      AppColors.ink,
      AppColors.terracotta,
      AppColors.accent,
      AppColors.primary,
      AppColors.kraft,
    ],
    [
      AppColors.primary,
      AppColors.kraft,
      AppColors.ink,
      AppColors.accent,
      AppColors.terracotta,
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = unitSize ?? math.max(size.height, 1.0);
    final k = s / 120;
    final rows = (size.height / s).ceil();
    final columns = (size.width / s).ceil();
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final palette = _palettes[(column + row) % _palettes.length];
        final origin = Offset(column * s, row * s);
        final rect = origin & Size(s, s);
        canvas.save();
        canvas.clipRect(rect);
        canvas.drawRect(rect, Paint()..color = palette[0]);
        final center = rect.center;
        canvas.drawCircle(
          center,
          38 * k,
          Paint()
            ..color = palette[1]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10 * k,
        );
        canvas.drawCircle(center, 20 * k, Paint()..color = palette[2]);
        canvas.drawCircle(center, 7 * k, Paint()..color = palette[3]);
        final corner = Paint()..color = palette[4];
        final faded = Paint()..color = palette[1].withValues(alpha: 0.55);
        canvas.drawCircle(rect.topLeft, 26 * k, corner);
        canvas.drawCircle(rect.bottomRight, 26 * k, corner);
        canvas.drawCircle(rect.topRight, 26 * k, faded);
        canvas.drawCircle(rect.bottomLeft, 26 * k, faded);
        final dot = Paint()..color = palette[3];
        for (final anchor in [
          Offset(center.dx, origin.dy + 11 * k),
          Offset(center.dx, origin.dy + 109 * k),
          Offset(origin.dx + 11 * k, center.dy),
          Offset(origin.dx + 109 * k, center.dy),
        ]) {
          canvas.drawPath(
            Path()
              ..moveTo(anchor.dx, anchor.dy - 7 * k)
              ..lineTo(anchor.dx + 5 * k, anchor.dy)
              ..lineTo(anchor.dx, anchor.dy + 7 * k)
              ..lineTo(anchor.dx - 5 * k, anchor.dy)
              ..close(),
            dot,
          );
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaxPainter oldDelegate) =>
      oldDelegate.unitSize != unitSize;
}

/// Image produit : photo de l'API si elle existe, sinon le motif wax.
class ProductArtwork extends StatelessWidget {
  const ProductArtwork({super.key, this.url, this.unitSize});

  final String? url;
  final double? unitSize;

  @override
  Widget build(BuildContext context) {
    final fallback = WaxPattern(unitSize: unitSize);
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
