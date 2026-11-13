import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'models/comparison_offer.dart';

/// Short verdict shown on the proof line, from the API verdict code.
String trustVerdictLabel(PriceTrust trust) => switch (trust.verdict) {
  'reliable' => 'Fiable',
  'to_confirm' => 'Plutôt fiable',
  'doubtful' => 'À vérifier',
  _ => trust.verdictLabel,
};

Color _verdictColor(String verdict) => switch (verdict) {
  'reliable' => AppColors.primary,
  'doubtful' => AppColors.error,
  _ => AppColors.warning,
};

IconData _verdictIcon(String verdict) => switch (verdict) {
  'reliable' => Icons.verified_outlined,
  'doubtful' => Icons.report_gmailerrorred_outlined,
  _ => Icons.help_outline,
};

/// Proof line of a price: the verdict, then the API's explanation ("Confirmé
/// il y a 2 h, vérifié par un modérateur.").
class TrustLine extends StatelessWidget {
  const TrustLine({super.key, required this.trust});

  final PriceTrust trust;

  @override
  Widget build(BuildContext context) {
    final color = _verdictColor(trust.verdict);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '${trustVerdictLabel(trust)}. ${trust.explanation}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_verdictIcon(trust.verdict), size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: trustVerdictLabel(trust),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: ' · ${trust.explanation}'),
                ],
              ),
              style: textTheme.bodySmall?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
