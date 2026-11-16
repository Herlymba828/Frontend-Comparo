import 'package:flutter/material.dart';

import 'common.dart';
import 'tokens.dart';

/// Rôle d'une étiquette de prix.
enum PriceTagKind {
  /// Le seul meilleur prix d'un produit (citron).
  best,

  /// Économie réalisée (« −800 F »).
  save,

  /// Badge « Bêta » ou « Promo » : même forme, autre token.
  beta,
  promo,
}

/// L'étiquette : coin gauche en pointe et trou de suspension
/// (classes `.tag` / `.big-tag` du prototype, `PriceTag variant="tag"` du design system).
class PriceTag extends StatelessWidget {
  const PriceTag.amount(
    num this.amount, {
    super.key,
    this.kind = PriceTagKind.best,
    this.large = false,
    this.currency = 'FCFA',
  }) : text = null;

  const PriceTag.text(
    String this.text, {
    super.key,
    this.kind = PriceTagKind.save,
  })  : amount = null,
        large = false,
        currency = '';

  final num? amount;
  final String? text;
  final PriceTagKind kind;

  /// Grande étiquette de la fiche produit (26/30).
  final bool large;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    final (bg, fg) = switch (kind) {
      PriceTagKind.best => (c.priceBestBg, c.priceBestFg),
      PriceTagKind.save => (c.saveBg, c.saveFg),
      PriceTagKind.beta => (c.badgeBetaBg, c.badgeBetaFg),
      PriceTagKind.promo => (c.badgePromoBg, c.badgePromoFg),
    };
    final label = text ?? '${formatXaf(amount!)}${currency.isEmpty ? '' : ' $currency'}';
    final style = large
        ? ComparoText.priceLg.copyWith(fontSize: 26, height: 30 / 26, color: fg)
        : const TextStyle(
            fontFamily: ComparoText.fontSans,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontVariations: [FontVariation('wght', 800)],
          ).copyWith(color: fg);
    final notch = large ? 14.0 : 12.0;
    final pad = large
        ? const EdgeInsets.fromLTRB(26, 6, 14, 6)
        : const EdgeInsets.fromLTRB(22, ComparoDims.space1, ComparoDims.space3, ComparoDims.space1);
    final hole = large ? 7.0 : 6.0;
    return Semantics(
      label: kind == PriceTagKind.best && amount != null ? 'Meilleur prix : $label' : label,
      excludeSemantics: true,
      child: ClipPath(
        clipper: _TagClipper(notch: notch, radius: 7),
        child: Container(
          color: bg,
          padding: pad,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: (large ? 10 : 8) - pad.left,
                child: Container(
                  width: hole,
                  height: hole,
                  decoration: BoxDecoration(color: c.paper, shape: BoxShape.circle),
                ),
              ),
              Text(label, style: style, maxLines: 1, softWrap: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagClipper extends CustomClipper<Path> {
  const _TagClipper({required this.notch, required this.radius});
  final double notch;
  final double radius;

  @override
  Path getClip(Size s) {
    final r = radius;
    return Path()
      ..moveTo(notch, 0)
      ..lineTo(s.width - r, 0)
      ..arcToPoint(Offset(s.width, r), radius: Radius.circular(r))
      ..lineTo(s.width, s.height - r)
      ..arcToPoint(Offset(s.width - r, s.height), radius: Radius.circular(r))
      ..lineTo(notch, s.height)
      ..lineTo(0, s.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(_TagClipper old) => old.notch != notch || old.radius != radius;
}

/// Prix sans étiquette (`.pnum`) : toutes les offres sauf la meilleure.
class PricePlain extends StatelessWidget {
  const PricePlain(this.amount, {super.key, this.currency = 'FCFA'});
  final num amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: formatXaf(amount), style: ComparoText.pricePlain.copyWith(color: c.ink)),
        TextSpan(
          text: ' $currency',
          style: const TextStyle(
            fontFamily: ComparoText.fontSans,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontVariations: [FontVariation('wght', 700)],
          ).copyWith(color: c.inkMuted),
        ),
      ]),
      maxLines: 1,
      softWrap: false,
    );
  }
}

/// Écart au meilleur prix (`.ecart`) : « +400 F ». Rien si le prix est le meilleur.
class PriceGap extends StatelessWidget {
  const PriceGap({super.key, required this.price, required this.best});
  final num price;
  final num best;

  @override
  Widget build(BuildContext context) {
    if (price <= best) return const SizedBox.shrink();
    return Semantics(
      label: '${formatXaf(price - best)} francs de plus que le meilleur prix',
      excludeSemantics: true,
      child: Text('+${formatXaf(price - best)} F',
          style: ComparoText.priceGap.copyWith(color: context.comparo.inkMuted)),
    );
  }
}
