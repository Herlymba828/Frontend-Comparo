import 'package:comparo_ui/comparo_ui.dart';
import 'package:comparo_ui/demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const offers = [
  PriceLineOffer(price: 5350, vendor: 'Supérette Bel-Air'),
  PriceLineOffer(price: 4950, vendor: 'Épicerie du Rond-Point'),
  PriceLineOffer(price: 5100, vendor: 'Dépôt Owendo Gros'),
  PriceLineOffer(price: 5600, vendor: 'Boutique Sainte-Anne'),
];

void main() {
  setUpAll(loadComparoFonts);

  group('format et règles', () {
    test('montants avec espace fine insécable, comme le prototype', () {
      expect(formatXaf(4950), '4 950');
      expect(formatXaf(1234567), '1 234 567');
      expect(formatXaf(350), '350');
    });
    test('écart au prix connu', () {
      expect(priceDeviationPercent(7200, 4950), 45);
      expect(priceDeviationPercent(3000, 4950), -39);
    });
    test('nom de vendeur raccourci', () {
      expect(shortVendorName('Épicerie du Rond-Point'), 'Rond-Point');
      expect(shortVendorName('Boutique Sainte-Anne'), 'Sainte-Anne');
      expect(shortVendorName('Marché central · étal 14'), 'Marché éta…');
    });
  });

  group('PriceLine : géométrie', () {
    test('la moins chère est à gauche et marquée « best »', () {
      final l = PriceLineLayout(offers, true);
      expect(l.items.first.offer.price, 4950);
      expect(l.items.first.best, isTrue);
      expect(l.items.where((i) => i.best), hasLength(1));
      expect(l.items.first.x, lessThan(l.items.last.x));
    });
    test('en grand, les étiquettes trop proches descendent d’un rang', () {
      final l = PriceLineLayout(offers, true);
      expect(l.items.map((i) => i.level).toList(), [0, 1, 0, 0]);
      for (var a = 0; a < l.items.length; a++) {
        for (var b = a + 1; b < l.items.length; b++) {
          if (l.items[a].level == l.items[b].level) {
            expect(
                l.tagRect(l.items[a]).overlaps(l.tagRect(l.items[b])), isFalse,
                reason: 'étiquettes $a et $b');
          }
        }
      }
    });
    test('en petit, 16 unités au moins entre deux étiquettes', () {
      final l = PriceLineLayout(const [
        PriceLineOffer(price: 100, vendor: 'a'),
        PriceLineOffer(price: 101, vendor: 'b'),
        PriceLineOffer(price: 200, vendor: 'c')
      ], false);
      expect(l.items[1].x - l.items[0].x, greaterThanOrEqualTo(16));
    });
    test('deux offres au même prix : centrées, côte à côte', () {
      final l = PriceLineLayout(const [
        PriceLineOffer(price: 100, vendor: 'a'),
        PriceLineOffer(price: 100, vendor: 'b')
      ], true);
      expect(l.items.first.x, 170);
      expect(l.items.first.best, isTrue);
      expect(l.items.where((i) => i.best), hasLength(1));
    });
  });

  group('PriceLine : accessibilité', () {
    testWidgets(
        'chaque étiquette est un bouton annoncé, de 48 px au moins (règle Android)',
        (tester) async {
      final picked = <num>[];
      await pumpComparo(
          tester,
          inScaffold(SizedBox(
              width: 340,
              child: PriceLine(
                  offers: offers,
                  size: PriceLineSize.large,
                  onSelect: (o) => picked.add(o.price)))));
      final handle = tester.ensureSemantics();
      expect(
          find.bySemanticsLabel(
              'Épicerie du Rond-Point, 4 950 francs, le moins cher'),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Boutique Sainte-Anne, 5')),
          findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Supérette Bel-Air')));
      expect(picked, [5350]);
      handle.dispose();
    });

    testWidgets('utilisable au clavier : Tab puis Entrée', (tester) async {
      final picked = <num>[];
      await pumpComparo(
          tester,
          inScaffold(SizedBox(
              width: 340,
              child: PriceLine(
                  offers: offers,
                  size: PriceLineSize.large,
                  onSelect: (o) => picked.add(o.price)))));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(picked, hasLength(2));
    });

    testWidgets('sans onSelect : un seul résumé, aucune cible', (tester) async {
      await pumpComparo(
          tester,
          inScaffold(
              const SizedBox(width: 300, child: PriceLine(offers: offers))));
      expect(find.bySemanticsLabel(RegExp(r'^4 offres de 4.950 à 5.600')),
          findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('autres composants', () {
    testWidgets('ProofLine : un mot de verdict, jamais la couleur seule',
        (tester) async {
      await pumpComparo(
          tester,
          inScaffold(const Column(mainAxisSize: MainAxisSize.min, children: [
            ProofLine(
                level: ProofLevel.high,
                age: 'hier',
                source: ProofSource.vendor),
            ProofLine(
                level: ProofLevel.medium,
                age: 'il y a 2 j',
                source: ProofSource.field),
            ProofLine(level: ProofLevel.low),
          ])));
      expect(find.bySemanticsLabel('Vu hier · vendeur vérifié · Fiable'),
          findsOneWidget);
      expect(
          find.bySemanticsLabel(
              'Vu il y a 2 j · relevé terrain · Plutôt fiable'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Vu à une date inconnue · À vérifier'),
          findsOneWidget);
    });

    testWidgets('OfferTile : bouton Ajouter de 48 px, annoncé avec le vendeur',
        (tester) async {
      var added = 0;
      await pumpComparo(
          tester,
          inScaffold(OfferTile(
              vendor: 'Supérette Bel-Air',
              price: 5350,
              bestPrice: 4950,
              onAdd: () => added++,
              proof: const ProofLine(
                  level: ProofLevel.medium, age: 'il y a 9 j'))));
      final add = find.bySemanticsLabel('Ajouter Supérette Bel-Air à ma liste');
      expect(add, findsOneWidget);
      expect(tester.getSize(find.byType(OutlinedButton)), const Size(48, 48));
      expect(find.text('+400 F'), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      expect(added, 1);
    });

    testWidgets('MarketSlate : 5 lignes au plus, ligne cliquable de 48 px',
        (tester) async {
      await pumpComparo(
          tester,
          inScaffold(MarketSlate(title: 'Prix du jour', rows: [
            SlateRow(label: 'Riz', value: 4950, onTap: () {}, selected: true)
          ])));
      expect(
          find.bySemanticsLabel('Riz, 4 950 francs, choisi'), findsOneWidget);
      expect(
          tester
              .getSize(find.bySemanticsLabel('Riz, 4\u202F950 francs, choisi'))
              .height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('ChoiceCard : état sélectionné exposé', (tester) async {
      await pumpComparo(
          tester,
          inScaffold(const ChoiceCard(
              title: 'Tout au même endroit',
              amount: 14250,
              subtitle: 'Un seul déplacement',
              selected: true)));
      expect(tester.getSemantics(find.byType(ChoiceCard)),
          isSemantics(isSelected: true, isButton: true));
    });

    testWidgets('PriceInputTag : avertit au-delà de 30 % d’écart',
        (tester) async {
      final ctl = TextEditingController();
      await pumpComparo(tester,
          inScaffold(PriceInputTag(controller: ctl, knownLowest: 4950)));
      expect(find.byType(ComparoWarning), findsNothing);
      await tester.enterText(find.byType(TextField), '5200');
      await tester.pump();
      expect(find.byType(ComparoWarning), findsNothing);
      await tester.enterText(find.byType(TextField), '7200');
      await tester.pump();
      expect(find.textContaining('45 % au-dessus'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '12a');
      await tester.pump();
      expect(ctl.text, '12');
    });

    testWidgets('ComparoNavigationBar : onglet choisi et compteur annoncés',
        (tester) async {
      var tapped = -1;
      await pumpComparo(
          tester,
          Scaffold(
              bottomNavigationBar: ComparoNavigationBar(
                  currentIndex: 0,
                  onTap: (i) => tapped = i,
                  items: const [
                ComparoNavItem(icon: Icons.home_outlined, label: 'Accueil'),
                ComparoNavItem(
                    icon: Icons.checklist_rounded, label: 'Ma liste', badge: 5),
              ])));
      expect(find.bySemanticsLabel('Ma liste, 5 articles'), findsOneWidget);
      await tester.tap(find.text('Ma liste'));
      expect(tapped, 1);
    });
  });

  group('écrans de démonstration', () {
    for (final dark in [false, true]) {
      final theme = dark ? 'sombre' : 'clair';
      testWidgets('Fiche ($theme) : cibles tactiles et contrastes',
          (tester) async {
        await pumpComparo(tester, const FicheDemo(), dark: dark);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
      testWidgets('Accueil ($theme) : cibles tactiles et contrastes',
          (tester) async {
        await pumpComparo(tester, const AccueilDemo(), dark: dark);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
      testWidgets('Liste ($theme) : cibles tactiles et contrastes',
          (tester) async {
        await pumpComparo(tester, const ListeDemo(), dark: dark);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }
  });
}
