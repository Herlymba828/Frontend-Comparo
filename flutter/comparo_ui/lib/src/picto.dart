import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'common.dart';
import 'picto_paths.dart';
import 'tokens.dart';

enum PictoKind { riz, huile, sucre, lait, sardine, eau, savon, conserve }

/// Picto produit plat sur vignette, avec le repère de marque (initiale sur pastille).
/// Composant `Picto` du design system.
class ProductPicto extends StatelessWidget {
  const ProductPicto({super.key, required this.kind, this.brand, this.large = false}) : loading = false;

  /// Vignette seule, en attente des données.
  const ProductPicto.loading({super.key, this.large = false})
      : kind = PictoKind.riz,
        brand = null,
        loading = true;

  final bool loading;

  final PictoKind kind;

  /// « Marque A » : l'initiale choisit une des 5 couleurs `brand-mark-*`.
  final String? brand;

  /// 56 px (résultats de recherche) au lieu de 48 px.
  final bool large;

  static String svgFor(PictoKind kind, ComparoColors c) {
    final colors = {
      'illu-lemon': c.illuLemon,
      'illu-teal': c.illuTeal,
      'illu-green': c.illuGreen,
      'illu-soft': c.illuSoft,
      'illu-paper': c.illuPaper,
      'illu-shade': c.illuShade,
      'illu-line': c.illuLine,
    };
    var body = pictoPaths[kind.name] ?? pictoPaths['riz']!;
    colors.forEach((k, v) => body = body.replaceAll('{$k}', colorHex(v)));
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">$body</svg>';
  }

  static Color brandColor(String initial, ComparoColors c) {
    final marks = [c.brandMark1, c.brandMark2, c.brandMark3, c.brandMark4, c.brandMark5];
    return marks[initial.codeUnitAt(0) % 5];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    final side = large ? ComparoDims.thumbLg : ComparoDims.thumbMd;
    if (loading) return Skeleton(width: side, height: side, radius: large ? 14 : ComparoDims.radiusMd);
    final initial = brand?.replaceFirst('Marque ', '');
    return Semantics(
      excludeSemantics: true,
      label: brand,
      child: SizedBox(
        width: side,
        height: side,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: side,
            height: side,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.fill100,
              borderRadius: BorderRadius.circular(large ? 14 : ComparoDims.radiusMd),
            ),
            child: SvgPicture.string(svgFor(kind, c), width: side * .78, height: side * .78),
          ),
          if (initial != null && initial.isNotEmpty)
            Positioned(
              right: -7,
              bottom: -7,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(8)),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: brandColor(initial, c),
                    borderRadius: BorderRadius.circular(ComparoDims.radiusSm),
                  ),
                  child: Center(widthFactor: 1, child: Text(
                    initial.substring(0, 1),
                    style: const TextStyle(
                      fontFamily: ComparoText.fontSans,
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      fontVariations: [FontVariation('wght', 800)],
                    ).copyWith(color: c.onBrandMark),
                  )),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
