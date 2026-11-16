import 'package:flutter/material.dart';

import 'common.dart';
import 'price.dart';
import 'proof_line.dart';
import 'tokens.dart';

/// Titre de section accroché à la ficelle (`.sec`) : nœud, titre, fil pointillé.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        // Le titre prend sa largeur naturelle et passe à la ligne s'il ne tient pas (grand
        // texte) ; le fil pointillé remplit le reste, et disparaît quand il n'y a plus de place.
        child: LayoutBuilder(
          builder: (context, box) => Row(children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.sectionKnot, width: 2.5)),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: (box.maxWidth - 9 - 2 * 10).clamp(0.0, box.maxWidth)),
              child: Text(text,
                  style: const TextStyle(
                    fontFamily: ComparoText.fontDisplay,
                    fontSize: 19,
                    height: 24 / 19,
                    fontWeight: FontWeight.w800,
                    fontVariations: [FontVariation('wght', 800), FontVariation('opsz', 19)],
                  ).copyWith(color: c.ink)),
            ),
            const SizedBox(width: 10),
            Expanded(child: CustomPaint(size: const Size.fromHeight(2), painter: _DashPainter(c.cordeString.withValues(alpha: .7)))),
          ]),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double x = 0; x < size.width; x += 11) {
      canvas.drawRect(Rect.fromLTWH(x, 0, (size.width - x).clamp(0, 7).toDouble(), size.height), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Une offre de la liste sous la corde : vendeur et preuve à gauche,
/// prix et écart à droite, bouton « Ajouter » de 48 px.
class OfferTile extends StatelessWidget {
  const OfferTile({
    super.key,
    required this.vendor,
    required this.price,
    required this.bestPrice,
    required this.proof,
    this.stockLimited = false,
    this.onTap,
    this.onAdd,
  });

  final String vendor;
  final num price;
  final num bestPrice;
  final ProofLine proof;
  final bool stockLimited;

  /// Ouvre l'écran Fiabilité de l'offre.
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: ComparoDims.space3),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.lineSoft))),
      child: Row(children: [
        Expanded(
          child: Semantics(
            button: onTap != null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(vendor,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: ComparoText.fontSans, fontSize: 15, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])
                        .copyWith(color: c.ink)),
                const SizedBox(height: ComparoDims.space1),
                proof,
                if (stockLimited)
                  Text('Stock limité', style: ComparoText.caption.copyWith(color: c.inkMuted)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: ComparoDims.space3),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          PricePlain(price),
          const SizedBox(height: 2),
          PriceGap(price: price, best: bestPrice),
        ]),
        const SizedBox(width: ComparoDims.space3),
        Semantics(
          button: true,
          label: 'Ajouter $vendor à ma liste',
          excludeSemantics: true,
          onTap: onAdd,
          child: SizedBox(
            width: ComparoDims.targetMin,
            height: ComparoDims.targetMin,
            child: OutlinedButton(
              onPressed: onAdd,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(ComparoDims.targetMin),
                side: BorderSide(color: c.line),
                backgroundColor: c.paper,
                foregroundColor: c.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ComparoDims.radiusMd)),
              ),
              child: const Icon(Icons.add_rounded, size: ComparoDims.iconSm),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Choix d'achat de Ma liste (« Tout au même endroit », « Le moins cher · 2 arrêts »).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.amount,
    required this.subtitle,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final num amount;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.paper,
            borderRadius: BorderRadius.circular(ComparoDims.radiusCard),
            border: Border.all(
              color: selected ? c.primary : c.lineSoft,
              width: selected ? 2 : 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontFamily: ComparoText.fontSans, fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])
                        .copyWith(color: c.ink)),
              ),
              PricePlain(amount),
            ]),
            const SizedBox(height: 6),
            Text(subtitle, style: ComparoText.caption.copyWith(color: c.inkMuted)),
          ]),
        ),
      ),
    );
  }
}

/// Avertissement (`.warn`) : prix à vérifier avant l'envoi, prix ancien.
class ComparoWarning extends StatelessWidget {
  const ComparoWarning(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: ComparoDims.space3),
        decoration: BoxDecoration(color: c.warningBg, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 18, color: c.warningFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontFamily: ComparoText.fontSans, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, fontVariations: [FontVariation('wght', 600)])
                    .copyWith(color: c.warningFg)),
          ),
        ]),
      ),
    );
  }
}
