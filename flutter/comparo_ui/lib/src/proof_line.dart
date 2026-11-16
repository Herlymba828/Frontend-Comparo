import 'package:flutter/material.dart';

import 'common.dart';
import 'tokens.dart';

/// Niveau de preuve fourni par l'API (seuils côté serveur).
enum ProofLevel { high, medium, low }

/// Origine du prix.
enum ProofSource { vendor, field, unknown }

/// Ligne de preuve : une pastille, l'âge du prix, la source et un verdict en un mot.
/// Remplace la paire de badges fraîcheur + confiance (composant `ProofLine`).
class ProofLine extends StatelessWidget {
  const ProofLine({
    super.key,
    required this.level,
    this.age,
    this.source = ProofSource.unknown,
    this.offline = false,
  }) : loading = false;

  /// Pastille et texte en squelette.
  const ProofLine.loading({super.key})
      : level = ProofLevel.low,
        age = null,
        source = ProofSource.unknown,
        offline = false,
        loading = true;

  final bool loading;

  /// Âge calculé sur la date du cache, suivi de « · hors connexion ».
  final bool offline;

  final ProofLevel level;

  /// « il y a 2 j », « hier », « aujourd'hui » ; null = date inconnue.
  final String? age;
  final ProofSource source;

  static String verdictOf(ProofLevel l) => switch (l) {
        ProofLevel.high => 'Fiable',
        ProofLevel.medium => 'Plutôt fiable',
        ProofLevel.low => 'À vérifier',
      };

  String get _sourceText => switch (source) {
        ProofSource.vendor => ' · vendeur vérifié',
        ProofSource.field => ' · relevé terrain',
        ProofSource.unknown => '',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.comparo;
    if (loading) {
      return Semantics(
        label: 'Chargement',
        excludeSemantics: true,
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Skeleton(width: 14, height: 14, radius: 7),
          SizedBox(width: 6),
          Skeleton(width: 170, height: 12),
        ]),
      );
    }
    final base = const TextStyle(
      fontFamily: ComparoText.fontSans,
      fontSize: 12.5,
      height: 16 / 12.5,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', 600)],
    ).copyWith(color: c.inkMuted);
    final verdict = verdictOf(level);
    final prefix = 'Vu ${age ?? 'à une date inconnue'}$_sourceText · ';
    return Semantics(
      label: '$prefix$verdict${offline ? ' · hors connexion' : ''}',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Dot(level: level, colors: c),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(style: base, children: [
              TextSpan(text: prefix),
              TextSpan(text: verdict, style: base.copyWith(color: c.ink, fontWeight: FontWeight.w700, fontVariations: const [FontVariation('wght', 700)])),
              if (offline) const TextSpan(text: ' · hors connexion'),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.level, required this.colors});
  final ProofLevel level;
  final ComparoColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final ring = Border.all(color: c.proofLow, width: 1.5);
    return switch (level) {
      ProofLevel.high => Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.proofHigh, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, size: 10, color: c.onPrimary),
        ),
      ProofLevel.medium => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: ring,
            gradient: LinearGradient(
              colors: [c.proofMedium, c.proofMedium, c.paper, c.paper],
              stops: const [0, .5, .5, 1],
            ),
          ),
        ),
      ProofLevel.low => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(shape: BoxShape.circle, border: ring),
        ),
    };
  }
}
