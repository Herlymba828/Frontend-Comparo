import 'package:flutter/material.dart';

import 'tokens.dart';

/// Accès court aux couleurs Comparo du thème courant.
extension ComparoContext on BuildContext {
  ComparoColors get comparo =>
      Theme.of(this).extension<ComparoColors>() ?? ComparoColors.light;
}

/// Montant en FCFA sans décimales, milliers séparés par une espace fine
/// insécable (U+202F), comme le prototype : 4950 → « 4 950 ».
String formatXaf(num amount) {
  final digits = amount.round().abs().toString();
  final out = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Couleur au format #rrggbb (pour colorer les SVG des pictos).
String colorHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Écart en pourcentage d'un prix saisi par rapport au prix connu le plus bas.
/// Le relevé affiche un avertissement au-delà de [warningThreshold] (30 %).
int priceDeviationPercent(num entered, num knownLowest) =>
    ((entered - knownLowest) / knownLowest * 100).round();

const int warningThreshold = 30;

/// Nom de vendeur raccourci pour les étiquettes de la corde (10 caractères + « … »).
String shortVendorName(String name) {
  var n = name.replaceFirst(
      RegExp(r'^(Épicerie|Supérette|Boutique|Dépôt) (du |de la |)'), '');
  n = n.replaceFirst('Marché central · ', 'Marché ');
  return n.length > 11 ? '${n.substring(0, 10)}…' : n;
}

/// Bloc de chargement (squelette). Pulsation coupée si le système réduit les animations.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 12, this.radius = ComparoDims.radiusSm, this.color});
  final double? width;
  final double height;
  final double radius;
  final Color? color;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: widget.color ?? context.comparo.skeleton, borderRadius: BorderRadius.circular(widget.radius)),
    );
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Opacity(opacity: 1 - .5 * (1 - (2 * _c.value - 1).abs()), child: child),
        child: box,
      ),
    );
  }
}
