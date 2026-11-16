import 'package:flutter/material.dart';

import 'common.dart';
import 'price.dart';
import 'tokens.dart';

/// Carte « Ma liste de la semaine » de l'accueil : total au mieux et économie possible.
/// Composant `ListSummary` du design system.
class ListSummary extends StatelessWidget {
  const ListSummary({
    super.key,
    required this.count,
    this.best = 0,
    this.save = 0,
    this.onOpen,
    this.onStart,
    this.offline,
  }) : loading = false;

  const ListSummary.loading({super.key})
      : count = 0,
        best = 0,
        save = 0,
        onOpen = null,
        onStart = null,
        offline = null,
        loading = true;

  /// Nombre d'articles ; 0 = invitation à commencer la liste.
  final int count;

  /// Total au mieux (boutique unique ou découpage en arrêts, calculé par l'API).
  final num best;

  /// Économie face à la boutique la plus chère qui a toute la liste ; 0 = pas d'étiquette.
  final num save;
  final VoidCallback? onOpen;
  final VoidCallback? onStart;

  /// Date du cache : totaux affichés, économie non promise.
  final String? offline;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    final sub = ComparoText.subtitle.copyWith(color: c.ink);
    final cap = ComparoText.caption.copyWith(color: c.inkMuted);
    Widget card(List<Widget> children, {VoidCallback? onTap, String? label}) => Semantics(
          button: onTap != null,
          label: label,
          excludeSemantics: label != null,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ComparoDims.space4),
              decoration: BoxDecoration(
                color: c.paper,
                borderRadius: BorderRadius.circular(ComparoDims.radiusCard),
                border: Border.all(color: c.highlightRing, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
          ),
        );
    if (loading) {
      return Semantics(
        label: 'Chargement de ma liste',
        child: card(const [Skeleton(width: 190, height: 16), SizedBox(height: 10), Skeleton(width: 150, height: 26)]),
      );
    }
    if (count == 0) {
      return card([
        Text('Commencez votre liste de la semaine', style: sub),
        const SizedBox(height: 6),
        Text("Ajoutez vos produits : Comparo trouve la boutique la moins chère pour l'ensemble.", style: cap),
      ], onTap: onStart);
    }
    final showSave = save > 0 && offline == null;
    return card([
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text('Ma liste de la semaine', style: sub)),
        Text('$count articles', style: cap),
      ]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text('${formatXaf(best)} FCFA',
            style: const TextStyle(
              fontFamily: ComparoText.fontDisplay,
              fontSize: 24,
              height: 28 / 24,
              fontWeight: FontWeight.w800,
              fontVariations: [FontVariation('wght', 800), FontVariation('opsz', 24)],
              fontFeatures: [FontFeature.tabularFigures()],
            ).copyWith(color: c.ink)),
        const SizedBox(width: 10),
        Text('au mieux', style: cap),
      ]),
      if (showSave) ...[
        const SizedBox(height: 10),
        Row(children: [
          PriceTag.text('−${formatXaf(save)} F'),
          const SizedBox(width: 10),
          Expanded(child: Text("d'économie possible face à la boutique la plus chère", style: ComparoText.caption.copyWith(color: c.ink))),
        ]),
      ] else if (offline != null) ...[
        const SizedBox(height: 10),
        Text('Hors connexion · totaux du $offline', style: cap),
      ],
    ],
        onTap: onOpen,
        label: 'Ma liste de la semaine, $count articles, ${formatXaf(best)} francs au mieux'
            '${showSave ? ', ${formatXaf(save)} francs d\'économie possible' : ''}${offline != null ? ', hors connexion' : ''}');
  }
}
