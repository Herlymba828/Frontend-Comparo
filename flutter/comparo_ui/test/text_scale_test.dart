import 'package:comparo_ui/comparo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Taille de texte à 200 % : le réglage d'accessibilité le plus grand que
/// l'application doit supporter.
Widget _doubleText(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child,
      ),
    );

/// Un petit téléphone.
const _smallPhone = Size(320, 900);

void main() {
  setUpAll(loadComparoFonts);

  group('à 200 % de taille de texte sur 320 px', () {
    testWidgets('SectionTitle : un titre long passe à la ligne sans déborder',
        (tester) async {
      await pumpComparo(tester,
          _doubleText(inScaffold(const SectionTitle('Explorer par catégorie'))),
          size: _smallPhone);

      expect(tester.takeException(), isNull);
      expect(find.text('Explorer par catégorie'), findsOneWidget);
    });

    testWidgets('SectionTitle : un titre court garde son fil pointillé',
        (tester) async {
      await pumpComparo(tester, inScaffold(const SectionTitle('Offres')),
          size: _smallPhone);

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('MarketSlate : le libellé est coupé, jamais le prix',
        (tester) async {
      await pumpComparo(
        tester,
        _doubleText(inScaffold(const MarketSlate(
          title: 'Prix du jour',
          rows: [
            SlateRow(
                label: 'Riz parfumé démo — 1 kg, sac de qualité supérieure',
                value: 1650),
            SlateRow(label: 'Huile', value: 1350),
            SlateRow(label: 'Sucre en poudre', missing: 'manque 1'),
          ],
          footer: 'En FCFA · mis à jour il y a 2 h',
        ))),
        size: _smallPhone,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(formatXaf(1650)), findsOneWidget);
      expect(find.text(formatXaf(1350)), findsOneWidget);
    });
  });
}
