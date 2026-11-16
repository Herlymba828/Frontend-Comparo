import 'package:comparo_ui/demo_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Planche des états (animations coupées pour une capture stable).
void main() {
  setUpAll(loadComparoFonts);
  for (final dark in [false, true]) {
    testWidgets('états ${dark ? 'sombre' : 'clair'}', (tester) async {
      await pumpComparo(
          tester,
          const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: EtatsDemo()),
          dark: dark,
          size: const Size(390, 1640));
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/etats-${dark ? 'sombre' : 'clair'}.png'));
    });
  }
}
