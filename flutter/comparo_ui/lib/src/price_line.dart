import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'tokens.dart';

/// Une offre actuelle accrochée à la corde. Jamais un prix expiré ou épuisé.
@immutable
class PriceLineOffer {
  const PriceLineOffer({required this.price, required this.vendor, this.id});
  final num price;
  final String vendor;
  final Object? id;
}

enum PriceLineSize {
  /// Petite corde d'un résultat de recherche (à partir de 2 offres).
  small,

  /// Grande corde de la fiche produit, étiquettes avec prix et vendeur.
  large,
}

/// La corde à prix : les offres pendent à une ficelle, placées selon leur prix ;
/// la moins chère en citron, à gauche. Composant `PriceLine` du design system.
///
/// En grand, avec [onSelect], chaque étiquette est un bouton atteignable au
/// clavier (Entrée, Espace) et annoncé « vendeur, prix ».
class PriceLine extends StatefulWidget {
  const PriceLine({
    super.key,
    required this.offers,
    this.size = PriceLineSize.small,
    this.onSelect,
    this.loading = false,
    this.offline = false,
  });

  final List<PriceLineOffer> offers;
  final PriceLineSize size;
  final ValueChanged<PriceLineOffer>? onSelect;

  /// Ficelle seule et trois étiquettes en squelette.
  final bool loading;

  /// Données du cache : même rendu, le libellé vocal ajoute « hors connexion ».
  final bool offline;

  /// 8 offres au plus sur la corde ; les suivantes restent dans la liste.
  static const int maxOffers = 8;

  @override
  State<PriceLine> createState() => _PriceLineState();
}

/// Géométrie de la corde, en unités du dessin (largeur 340 ou 300).
class PriceLineLayout {
  PriceLineLayout(List<PriceLineOffer> offers, this.large)
      : sorted = ([...offers]..sort((a, b) => a.price.compareTo(b.price))).take(PriceLine.maxOffers).toList(),
        hidden = math.max(0, offers.length - PriceLine.maxOffers) {
    if (sorted.length < 2) return;
    final mn = sorted.first.price, mx = sorted.last.price;
    double xOf(num v) => mx == mn ? width / 2 : pad + (v - mn) / (mx - mn) * (width - 2 * pad);
    final last = [-999.0, -999.0, -999.0];
    final placed = [<double>[], <double>[], <double>[]];
    for (final of in sorted) {
      var x = xOf(of.price);
      var level = 0;
      if (large) {
        // 3 rangs ; si les trois sont pris à cet endroit, on essaie à droite puis à gauche,
        // un pas d'étiquette à la fois, en comparant à toutes les étiquettes déjà posées.
        final d = tagWidth + 4;
        bool fits(double cx, int lv) => placed[lv].every((p) => (cx - p).abs() >= d);
        final candidates = <double>[x];
        for (var k = 1; k <= 12; k++) {
          candidates..add(x + k * d)..add(x - k * d);
        }
        var found = false;
        for (final cx in candidates) {
          if (cx != x && (cx < tagWidth / 2 || cx > width - tagWidth / 2)) continue;
          for (var lv = 0; lv < 3 && !found; lv++) {
            if (fits(cx, lv)) {
              x = cx;
              level = lv;
              found = true;
            }
          }
          if (found) break;
        }
        if (!found) level = 2;
        placed[level].add(x);
      } else {
        if (x - last[0] < 16) x = last[0] + 16;
        last[0] = x;
      }
      items.add(PriceLineItem(of, math.min(x, width - 8), level, identical(of, sorted.first)));
    }
    final maxLevel = items.map((i) => i.level).reduce(math.max);
    height = (6 + 2 * sag + thread + maxLevel * rowHeight + tagHeight + (large ? 22 : 2)).ceilToDouble();
  }

  final bool large;
  final List<PriceLineOffer> sorted;

  /// Offres au-delà des 8 affichées.
  final int hidden;
  final List<PriceLineItem> items = [];
  double height = 0;

  double get width => large ? 340 : 300;
  double get sag => large ? 9 : 5;
  double get tagWidth => large ? 66 : 14;
  double get pad => large ? tagWidth / 2 + 2 : 10;
  double get thread => large ? 12 : 6;
  double get rowHeight => large ? 56 : 0;
  double get tagHeight => large ? 46 : 16;

  /// Hauteur de la ficelle (courbe quadratique) à l'abscisse x.
  double stringY(double x) {
    final t = x / width;
    return 6 + 4 * sag * t * (1 - t);
  }

  double tagTop(PriceLineItem it) => stringY(it.x) + thread + it.level * rowHeight;

  Rect tagRect(PriceLineItem it) {
    final top = tagTop(it);
    return Rect.fromLTWH(it.x - tagWidth / 2, top, tagWidth, tagHeight);
  }
}

class PriceLineItem {
  PriceLineItem(this.offer, this.x, this.level, this.best);
  final PriceLineOffer offer;
  final double x;
  final int level;
  final bool best;
}

class _PriceLineState extends State<PriceLine> {
  int? _focused;

  @override
  Widget build(BuildContext context) {
    final large = widget.size == PriceLineSize.large;
    if (widget.loading) return _skeleton(context, large);
    final layout = PriceLineLayout(widget.offers, large);
    if (layout.items.isEmpty) return const SizedBox.shrink();
    final c = context.comparo;
    final mn = layout.sorted.first.price, mx = layout.sorted.last.price;
    final n = layout.items.length;
    final hidden = layout.hidden;
    final summary = '$n offre${n > 1 ? 's' : ''} de ${formatXaf(mn)} à ${formatXaf(mx)} francs ; la moins chère en citron'
        '${hidden > 0 ? ' ; $hidden autre${hidden > 1 ? 's' : ''} non affichée${hidden > 1 ? 's' : ''}' : ''}${widget.offline ? ' ; hors connexion' : ''}';
    final line = _line(context, layout, c, large, summary);
    if (hidden == 0 || !large) return line;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      line,
      const SizedBox(height: ComparoDims.space1),
      Text('+$hidden autre${hidden > 1 ? 's' : ''} offre${hidden > 1 ? 's' : ''} dans la liste', style: ComparoText.caption.copyWith(color: c.inkMuted)),
    ]);
  }

  Widget _skeleton(BuildContext context, bool large) {
    final c = context.comparo;
    final w = large ? 340.0 : 300.0;
    return Semantics(
      label: 'Chargement des prix',
      excludeSemantics: true,
      child: LayoutBuilder(builder: (context, box) {
        final scale = (box.maxWidth.isFinite ? box.maxWidth : w) / w;
        final tw = (large ? 66.0 : 14.0) * scale, th = (large ? 46.0 : 16.0) * scale;
        return SizedBox(
          height: (large ? 74 : 28) * scale,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _StringPainter(c.cordeString, large ? 9 : 5, w))),
            for (final x in large ? [40.0, 170.0, 300.0] : [12.0, 150.0, 288.0])
              Positioned(left: x * scale - tw / 2, top: (large ? 22 : 12) * scale, child: Skeleton(width: tw, height: th, radius: large ? 5 : 2)),
          ]),
        );
      }),
    );
  }

  Widget _line(BuildContext context, PriceLineLayout layout, ComparoColors c, bool large, String summary) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : layout.width;
      final scale = w / layout.width;
      final painter = _CordePainter(layout, c, Directionality.of(context), _focused);
      final canvas = CustomPaint(size: Size(w, layout.height * scale), painter: painter);
      if (!large || widget.onSelect == null) {
        return Semantics(label: summary, excludeSemantics: true, child: canvas);
      }
      return Semantics(
        label: summary,
        child: Stack(children: [
          canvas,
          for (var i = 0; i < layout.items.length; i++) _hitTarget(layout, i, scale),
        ]),
      );
    });
  }

  Widget _hitTarget(PriceLineLayout layout, int i, double scale) {
    final it = layout.items[i];
    final r = layout.tagRect(it);
    // Cible tactile d'au moins 48 × 48 autour de l'étiquette.
    final hw = math.max(r.width * scale, ComparoDims.targetMin) / 2;
    final hh = math.max(r.height * scale, ComparoDims.targetMin) / 2;
    final center = r.center * scale;
    void select() => widget.onSelect!(it.offer);
    return Positioned(
      left: center.dx - hw,
      top: center.dy - hh,
      width: hw * 2,
      height: hh * 2,
      child: Semantics(
        button: true,
        label: '${it.offer.vendor}, ${formatXaf(it.offer.price)} francs${it.best ? ', le moins cher' : ''}',
        onTap: select,
        excludeSemantics: true,
        child: Focus(
          onFocusChange: (f) => setState(() => _focused = f ? i : (_focused == i ? null : _focused)),
          onKeyEvent: (node, e) {
            if (e is KeyDownEvent && (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.space)) {
              select();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: select),
        ),
      ),
    );
  }
}

class _CordePainter extends CustomPainter {
  _CordePainter(this.l, this.c, this.dir, this.focused);
  final PriceLineLayout l;
  final ComparoColors c;
  final TextDirection dir;
  final int? focused;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / l.width);
    final W = l.width;
    final string = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = c.cordeString;
    canvas.drawPath(Path()..moveTo(0, 6)..quadraticBezierTo(W / 2, 6 + 2 * l.sag, W, 6), string);
    final thread = Paint()
      ..strokeWidth = 1.2
      ..color = c.cordeString;
    for (final idx in List.generate(l.items.length, (i) => i).reversed) {
      final it = l.items[idx];
      final x = it.x, y = l.stringY(x), ty = l.tagTop(it);
      canvas.drawLine(Offset(x, y), Offset(x, ty), thread);
      final fill = Paint()..color = it.best ? c.priceBestBg : c.paper;
      final ink = it.best ? c.priceBestFg : c.ink;
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      if (l.large) {
        final hw = l.tagWidth / 2, h = l.tagHeight;
        final p = Path()
          ..moveTo(x - hw, ty + 10)
          ..lineTo(x, ty)
          ..lineTo(x + hw, ty + 10)
          ..lineTo(x + hw, ty + h - 5)
          ..arcToPoint(Offset(x + hw - 5, ty + h), radius: const Radius.circular(5))
          ..lineTo(x - hw + 5, ty + h)
          ..arcToPoint(Offset(x - hw, ty + h - 5), radius: const Radius.circular(5))
          ..close();
        canvas.drawPath(p, fill);
        final isFocused = focused == idx;
        canvas.drawPath(
            p,
            edge
              ..strokeWidth = isFocused ? 3 : 1.2
              ..color = isFocused ? c.focus : (it.best ? c.priceBestBg : c.cordeString));
        canvas.drawCircle(Offset(x, ty + 8), 2.4, Paint()..color = c.canvas);
        canvas.drawCircle(
            Offset(x, ty + 8),
            2.4,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = it.best ? c.priceBestFg : c.cordeString);
        _text(canvas, formatXaf(it.offer.price), ComparoText.cordePrice.copyWith(color: ink), x, ty + 28);
        _text(canvas, shortVendorName(it.offer.vendor),
            ComparoText.cordeVendor.copyWith(color: ink.withValues(alpha: .8)), x, ty + 40);
      } else {
        final p = Path()
          ..moveTo(x - 7, ty + 5)
          ..lineTo(x, ty)
          ..lineTo(x + 7, ty + 5)
          ..lineTo(x + 7, ty + 16)
          ..lineTo(x - 7, ty + 16)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(
            p,
            edge
              ..strokeWidth = 1.1
              ..color = it.best ? c.priceBestFg : c.cordeString);
        canvas.drawCircle(Offset(x, ty + 5), 1.4, Paint()..color = c.canvas);
      }
    }
    if (l.large) {
      final s = const TextStyle(
        fontFamily: ComparoText.fontSans,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        fontVariations: [FontVariation('wght', 700)],
      ).copyWith(color: c.inkMuted);
      _text(canvas, 'moins cher', s, 0, l.height - 3, align: -1);
      _text(canvas, 'plus cher', s, W, l.height - 3, align: 1);
    }
    canvas.restore();
  }

  /// Écrit un texte dont la ligne de base passe par y ; align -1 gauche, 0 centre, 1 droite.
  void _text(Canvas canvas, String s, TextStyle style, double x, double baseline, {int align = 0}) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: dir, maxLines: 1)..layout();
    final b = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final maxW = align == 0 ? l.tagWidth - 10 : double.infinity;
    if (tp.width > maxW) {
      final sx = maxW / tp.width;
      canvas.save();
      canvas.translate(x - maxW / 2, baseline - b);
      canvas.scale(sx, 1);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
      return;
    }
    final dx = align == -1 ? x : align == 1 ? x - tp.width : x - tp.width / 2;
    tp.paint(canvas, Offset(dx, baseline - b));
  }

  @override
  bool shouldRepaint(_CordePainter old) => old.l != l || old.c != c || old.focused != focused;
}

class _StringPainter extends CustomPainter {
  _StringPainter(this.color, this.sag, this.width);
  final Color color;
  final double sag;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / width);
    canvas.drawPath(
        Path()..moveTo(0, 6)..quadraticBezierTo(width / 2, 6 + 2 * sag, width, 6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(_StringPainter old) => old.color != color;
}
