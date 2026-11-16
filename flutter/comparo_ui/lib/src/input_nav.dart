import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'layout.dart';
import 'tokens.dart';

/// Champ de prix en forme d'étiquette citron (`.tag-in`) : le montant se tape
/// comme on le lit sur l'étiquette. Avec [knownLowest], un écart de plus de 30 %
/// affiche un avertissement avant l'envoi.
class PriceInputTag extends StatefulWidget {
  const PriceInputTag({super.key, required this.controller, this.knownLowest, this.label = "Prix écrit sur l'étiquette"});

  final TextEditingController controller;
  final num? knownLowest;
  final String label;

  @override
  State<PriceInputTag> createState() => _PriceInputTagState();
}

class _PriceInputTagState extends State<PriceInputTag> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    widget.controller.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _focus.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(widget.controller.text.replaceAll(RegExp(r'\D'), ''));

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    final known = widget.knownLowest;
    final v = _value;
    final dev = (v != null && known != null && known > 0) ? priceDeviationPercent(v, known) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.label, style: ComparoText.label.copyWith(color: c.ink, fontSize: 13)),
      const SizedBox(height: 6),
      // Anneau de focus décalé de 3 px, hors du flux comme `outline` sur le web.
      Stack(clipBehavior: Clip.none, children: [
        if (_focus.hasFocus)
          Positioned(
            left: -5,
            top: -5,
            right: -5,
            bottom: -5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ComparoDims.radiusCard + 3),
                  border: Border.all(color: c.focus, width: 2),
                ),
              ),
            ),
          ),
        ClipPath(
          clipper: const _InputTagClipper(),
          child: Container(
            color: c.priceInputBg,
            padding: const EdgeInsets.fromLTRB(44, ComparoDims.space2, 18, ComparoDims.space2),
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
              Positioned(
                left: 18 - 44,
                child: Container(width: 11, height: 11, decoration: BoxDecoration(color: c.canvas, shape: BoxShape.circle)),
              ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    cursorColor: c.priceInputFg,
                    style: const TextStyle(
                      fontFamily: ComparoText.fontDisplay,
                      fontSize: 36,
                      height: 46 / 36,
                      fontWeight: FontWeight.w800,
                      fontVariations: [FontVariation('wght', 800), FontVariation('opsz', 36)],
                      fontFeatures: [FontFeature.tabularFigures()],
                    ).copyWith(color: c.priceInputFg),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: known == null ? '0' : formatXaf(known),
                      hintStyle: TextStyle(color: c.priceInputFg.withValues(alpha: .28)),
                      semanticCounterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: ComparoDims.space2),
                Text('FCFA',
                    style: const TextStyle(fontFamily: ComparoText.fontSans, fontSize: 14, fontWeight: FontWeight.w800, fontVariations: [FontVariation('wght', 800)])
                        .copyWith(color: c.priceInputFg)),
              ]),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Text(known == null ? 'Aucun prix connu pour ce produit' : 'Prix connu le plus bas : ${formatXaf(known)} FCFA',
          style: ComparoText.caption.copyWith(color: c.inkMuted)),
      if (dev != null && dev.abs() >= warningThreshold) ...[
        const SizedBox(height: ComparoDims.space2),
        ComparoWarning(
            'Ce prix est ${dev.abs()} % ${dev > 0 ? 'au-dessus' : 'en dessous'} des prix connus. Vérifiez le format et le montant avant d\'envoyer.'),
      ],
    ]);
  }
}

class _InputTagClipper extends CustomClipper<Path> {
  const _InputTagClipper();
  @override
  Path getClip(Size s) {
    const r = 14.0, notch = 24.0;
    return Path()
      ..moveTo(notch, 0)
      ..lineTo(s.width - r, 0)
      ..arcToPoint(Offset(s.width, r), radius: const Radius.circular(r))
      ..lineTo(s.width, s.height - r)
      ..arcToPoint(Offset(s.width - r, s.height), radius: const Radius.circular(r))
      ..lineTo(notch, s.height)
      ..lineTo(0, s.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

@immutable
class ComparoNavItem {
  const ComparoNavItem({required this.icon, required this.label, this.badge});
  final IconData icon;
  final String label;

  /// Compteur (articles de Ma liste) ; null ou 0 = pas de pastille.
  final int? badge;
}

/// Barre d'onglets : l'onglet actif porte la mini-étiquette citron.
/// Onglets attendus : Accueil, Recherche, Ma liste, Profil.
class ComparoNavigationBar extends StatelessWidget {
  const ComparoNavigationBar({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<ComparoNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    return Container(
      decoration: BoxDecoration(color: c.paper, border: Border(top: BorderSide(color: c.lineSoft))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == currentIndex,
                label: items[i].label + ((items[i].badge ?? 0) > 0 ? ', ${items[i].badge} articles' : ''),
                excludeSemantics: true,
                child: InkResponse(
                  onTap: () => onTap(i),
                  child: _NavCell(item: items[i], on: i == currentIndex, c: c),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.on, required this.c});
  final ComparoNavItem item;
  final bool on;
  final ComparoColors c;

  @override
  Widget build(BuildContext context) {
    final color = on ? c.primary : c.inkMuted;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ComparoDims.targetMin),
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, ComparoDims.space2, 0, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(item.icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(item.label,
                style: const TextStyle(fontFamily: ComparoText.fontSans, fontSize: 11, fontWeight: FontWeight.w700, fontVariations: [FontVariation('wght', 700)])
                    .copyWith(color: color)),
          ]),
        ),
        if (on)
          Positioned(top: 0, child: ClipPath(clipper: const _IndicatorClipper(), child: Container(width: 26, height: 8, color: c.navIndicator))),
        if ((item.badge ?? 0) > 0)
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.translate(
                offset: const Offset(15, 0),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(color: c.badgeCountBg, borderRadius: BorderRadius.circular(ComparoDims.radiusPill)),
                  child: Center(widthFactor: 1, child: Text(item.badge! > 99 ? '99+' : '${item.badge}',
                      style: const TextStyle(fontFamily: ComparoText.fontSans, fontSize: 10, height: 1, fontWeight: FontWeight.w800, fontVariations: [FontVariation('wght', 800)])
                          .copyWith(color: c.badgeCountFg))),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Mini-étiquette : rectangle dont le bas se termine en pointe.
class _IndicatorClipper extends CustomClipper<Path> {
  const _IndicatorClipper();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height / 2)
    ..lineTo(s.width / 2, s.height)
    ..lineTo(0, s.height / 2)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
