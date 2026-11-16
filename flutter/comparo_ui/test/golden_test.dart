import 'package:comparo_ui/demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Captures de référence (390 × 844, x2) avec les vraies polices.
/// Régénérer : flutter test --update-goldens test/golden_test.dart
void main() {
  setUpAll(loadComparoFonts);

  final screens = <String, Widget Function()>{
    'fiche': () => const FicheDemo(),
    'liste': () => const ListeDemo(),
    'accueil': () => const AccueilDemo(),
    'accueil-sans-liste': () => const AccueilDemo(withList: false),
    'accueil-hors-connexion': () => const AccueilDemo(offline: '3 nov., 18:40'),
  };
  for (final e in screens.entries) {
    for (final dark in [false, true]) {
      testWidgets('${e.key} ${dark ? 'sombre' : 'clair'}', (tester) async {
        await pumpComparo(tester, e.value(), dark: dark);
        // Laisse flutter_svg décoder les pictos.
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pumpAndSettle();
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                'goldens/${e.key}-${dark ? 'sombre' : 'clair'}.png'));
      });
    }
  }
}
