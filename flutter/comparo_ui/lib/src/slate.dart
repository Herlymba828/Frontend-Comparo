import 'package:flutter/material.dart';

import 'common.dart';
import 'tokens.dart';

/// Une ligne « produit ........ prix » de l'ardoise.
@immutable
class SlateRow {
  const SlateRow({required this.label, this.value, this.missing, this.selected = false, this.onTap});
  final String label;

  /// Montant en FCFA ; ignoré si [missing] est renseigné.
  final num? value;

  /// Remplace le prix : « manque 1 ».
  final String? missing;
  final bool selected;
  final VoidCallback? onTap;
}

/// L'ardoise du marché : Prix du jour, Ma liste par boutique, tableau du marchand.
/// Composant `Slate` du design system. 5 lignes au plus ; toujours une date en pied.
class MarketSlate extends StatelessWidget {
  const MarketSlate({
    super.key,
    this.title,
    this.meta,
    required this.rows,
    this.footer,
    this.loading = false,
    this.error = false,
    this.onRetry,
    this.offline,
    this.emptyText = 'Pas encore de prix du jour dans votre zone.',
  });

  /// 5 lignes au plus ; les suivantes ne sont pas affichées.
  static const int maxRows = 5;

  final String? title;
  final String? meta;
  final List<SlateRow> rows;
  final String? footer;

  /// 3 lignes en squelette.
  final bool loading;

  /// « Prix du jour indisponible. » + Réessayer.
  final bool error;
  final VoidCallback? onRetry;

  /// Date du cache (« prix du 3 nov., 18:40 ») : le pied devient « Hors connexion · … ».
  final String? offline;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    final muted = const TextStyle(
      fontFamily: ComparoText.fontSans,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', 600)],
    ).copyWith(color: c.slateMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: ComparoDims.space4),
      decoration: BoxDecoration(color: c.slate, borderRadius: BorderRadius.circular(ComparoDims.radiusLg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null || meta != null)
          Padding(
            padding: const EdgeInsets.only(bottom: ComparoDims.space1),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: ComparoDims.space2,
              children: [
                if (title != null)
                  Text(title!, style: ComparoText.title.copyWith(color: c.onSlate, fontWeight: FontWeight.w800, height: 24 / 20, fontVariations: const [FontVariation('wght', 800), FontVariation('opsz', 20)])),
                if (meta != null) Text(meta!, style: muted),
              ],
            ),
          ),
        ..._body(c),
        if (_footer != null && !error) Padding(padding: const EdgeInsets.only(top: ComparoDims.space1), child: Text(_footer!, style: muted)),
      ]),
    );
  }

  String? get _footer => offline != null ? 'Hors connexion · $offline' : footer;

  List<Widget> _body(ComparoColors c) {
    final msg = const TextStyle(fontFamily: ComparoText.fontSans, fontSize: 15, fontWeight: FontWeight.w600, fontVariations: [FontVariation('wght', 600)]).copyWith(color: c.onSlate);
    if (loading) {
      return [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Skeleton(width: 130 - i * 18.0, height: 14, color: c.slateMuted.withValues(alpha: .25)),
              const Spacer(),
              Skeleton(width: 54, height: 20, color: c.slateMuted.withValues(alpha: .25)),
            ]),
          ),
      ];
    }
    if (error) {
      return [
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ComparoDims.space3),
            child: Row(children: [
              Expanded(child: Text('Prix du jour indisponible.', style: msg)),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: c.linkOnDark, minimumSize: const Size(ComparoDims.targetMin, ComparoDims.targetMin)),
                  child: const Text('Réessayer', style: TextStyle(fontFamily: ComparoText.fontSans, fontSize: 15, fontWeight: FontWeight.w800, fontVariations: [FontVariation('wght', 800)])),
                ),
            ]),
          ),
        ),
      ];
    }
    if (rows.isEmpty) return [Padding(padding: const EdgeInsets.symmetric(vertical: ComparoDims.space3), child: Text(emptyText, style: msg))];
    assert(() {
      if (rows.length > maxRows) debugPrint('MarketSlate : $maxRows lignes au plus, ${rows.length - maxRows} ignorée(s).');
      return true;
    }());
    return [for (final r in rows.take(maxRows)) _row(r, c)];
  }

  Widget _row(SlateRow r, ComparoColors c) {
    final label = TextStyle(
      fontFamily: ComparoText.fontSans,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation('wght', 600)],
      color: c.onSlate,
    );
    final valueText = r.missing ?? (r.value == null ? '—' : formatXaf(r.value!));
    final valueStyle = r.missing != null
        ? const TextStyle(fontFamily: ComparoText.fontSans, fontSize: 13, fontWeight: FontWeight.w600, fontVariations: [FontVariation('wght', 600)]).copyWith(color: c.slateMuted)
        : const TextStyle(
            fontFamily: ComparoText.fontDisplay,
            fontSize: 22,
            height: 24 / 22,
            fontWeight: FontWeight.w800,
            fontVariations: [FontVariation('wght', 800), FontVariation('opsz', 22)],
            fontFeatures: [FontFeature.tabularFigures()],
          ).copyWith(color: c.onSlate);
    final value = Text(valueText, style: valueStyle);
    // Le libellé prend sa largeur naturelle, coupé avec « … » au-delà de 68 % de la ligne
    // et sans jamais pousser le prix hors de la ligne (le prix n'est jamais coupé, même à
    // 200 % de taille de texte) ; les pointillés remplissent le reste (Flutter ne
    // redistribue pas l'espace d'un Flexible).
    Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, box) {
          // Mesuré avec le style hérité (espacement des lettres du thème) : c'est celui du vrai texte.
          final valueWidth = (TextPainter(
            text: TextSpan(text: valueText, style: DefaultTextStyle.of(context).style.merge(valueStyle)),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout())
              .width;
          final labelRoom = box.maxWidth - valueWidth - 2 * ComparoDims.space2;
          return Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: (labelRoom < box.maxWidth * .68 ? labelRoom : box.maxWidth * .68).clamp(0.0, box.maxWidth)),
            child: Text.rich(
              TextSpan(text: r.label, style: label, children: [
                if (r.selected) TextSpan(text: ' ✓', style: label.copyWith(color: c.slateHighlight)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: ComparoDims.space2),
          Expanded(child: _Dots(color: c.slateMuted, style: label)),
          const SizedBox(width: ComparoDims.space2),
          value,
        ]);
        },
      ),
    );
    final spoken = '${r.label}, ${r.missing ?? (r.value == null ? 'prix inconnu' : '${formatXaf(r.value!)} francs')}${r.selected ? ', choisi' : ''}';
    if (r.onTap == null) return Semantics(label: spoken, excludeSemantics: true, child: row);
    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      onTap: r.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: r.onTap,
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: ComparoDims.targetMin), child: row),
      ),
    );
  }
}

/// Pointillés de conduite, 2 px, 4 px au-dessus de la ligne de base (comme le web).
/// Un texte transparent donne au trait la ligne de base de la rangée.
class _Dots extends StatelessWidget {
  const _Dots({required this.color, required this.style});
  final Color color;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Stack(children: [
        Text(' ', style: style.copyWith(color: Colors.transparent)),
        Positioned.fill(child: CustomPaint(painter: _DotsPainter(color.withValues(alpha: .6), style, Directionality.of(context)))),
      ]);
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color, this.style, this.dir);
  final Color color;
  final TextStyle style;
  final TextDirection dir;
  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(text: TextSpan(text: ' ', style: style), textDirection: dir)..layout();
    final y = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic) - 5;
    final p = Paint()..color = color;
    for (double x = 1; x < size.width; x += 4) {
      canvas.drawCircle(Offset(x, y), 1, p);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color || old.style != style;
}
