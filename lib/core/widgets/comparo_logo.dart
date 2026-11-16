import 'package:comparo_ui/comparo_ui.dart';
import 'package:flutter/material.dart';

/// Largest text scale the logotype follows.
const _maxTextScale = 1.2;

/// Logotype provisoire : une mini-étiquette citron avec son trou, suivie de
/// « Comparo » en Bricolage Grotesque.
class ComparoLogo extends StatelessWidget {
  const ComparoLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.comparo;
    return Semantics(
      label: 'Comparo',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 16,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 5),
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
                right: Radius.circular(3),
              ),
            ),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: colors.canvas,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: ComparoDims.space2),
          // A logotype does not grow with the text size setting: the full name
          // stays announced by the semantics label above.
          Flexible(
            child: Text(
              'Comparo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: _maxTextScale),
              style: ComparoText.title.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w800,
                fontVariations: const [
                  FontVariation('wght', 800),
                  FontVariation('opsz', 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
