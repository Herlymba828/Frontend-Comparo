import 'package:comparo_ui/comparo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

List<PriceLineOffer> offersOf(List<num> prices) => [
      for (var i = 0; i < prices.length; i++)
        PriceLineOffer(
            price: prices[i],
            vendor: 'Vendeur ${String.fromCharCode(65 + i)} du quartier')
    ];

void noOverlap(PriceLineLayout l) {
  for (var a = 0; a < l.items.length; a++) {
    for (var b = a + 1; b < l.items.length; b++) {
      if (l.items[a].level == l.items[b].level) {
        expect(l.tagRect(l.items[a]).overlaps(l.tagRect(l.items[b])), isFalse,
            reason: 'étiquettes $a et $b');
      }
    }
  }
}

/// Monte un widget animé (squelette) sans attendre la fin de l'animation infinie.
Future<void> pumpLoading(WidgetTester t, Widget w) =>
    pumpComparo(t, inScaffold(w), settle: false);

void main() {
  setUpAll(loadComparoFonts);

  group('PriceLine : limites du contrat', () {
    test('8 offres au plus, les moins chères', () {
      final l = PriceLineLayout(
          offersOf(
              [6000, 4950, 5800, 5000, 5100, 5200, 5600, 5300, 7000, 6500]),
          true);
      expect(l.items, hasLength(8));
      expect(l.hidden, 2);
      expect(l.items.map((i) => i.offer.price), isNot(contains(7000)));
    });
    test('8 prix égaux : aucune étiquette ne se chevauche', () {
      noOverlap(PriceLineLayout(offersOf(List.filled(8, 4950)), true));
    });
    test('prix très proches : aucune étiquette ne se chevauche', () {
      noOverlap(PriceLineLayout(
          offersOf([4950, 4950, 4950, 4950, 5000, 5100, 5200, 5600]), true));
    });
    test('0 ou 1 offre : pas de corde', () {
      expect(PriceLineLayout(offersOf([4950]), true).items, isEmpty);
      expect(PriceLineLayout(const [], false).items, isEmpty);
    });
    testWidgets('au-delà de 8 : mention « +N autres offres »', (t) async {
      await pumpComparo(
          t,
          inScaffold(SizedBox(
              width: 340,
              child: PriceLine(
                  offers: offersOf([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
                      .map((i) => 4900 + i * 50)
                      .toList()),
                  size: PriceLineSize.large))));
      expect(find.text('+2 autres offres dans la liste'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'2 autres non affichées')),
          findsOneWidget);
    });
    testWidgets('hors connexion : annoncé', (t) async {
      await pumpComparo(
          t,
          inScaffold(SizedBox(
              width: 300,
              child:
                  PriceLine(offers: offersOf([4950, 5100]), offline: true))));
      expect(find.bySemanticsLabel(RegExp(r'hors connexion$')), findsOneWidget);
    });
    testWidgets('chargement : squelette annoncé', (t) async {
      await pumpLoading(
          t,
          const SizedBox(
              width: 340,
              child: PriceLine(
                  offers: [], size: PriceLineSize.large, loading: true)));
      expect(find.bySemanticsLabel('Chargement des prix'), findsOneWidget);
      expect(find.byType(Skeleton), findsNWidgets(3));
    });
  });

  group('MarketSlate : états', () {
    testWidgets('7 lignes → 5 affichées ; libellé long coupé sans débordement',
        (t) async {
      final rows = [
        for (var i = 0; i < 7; i++)
          SlateRow(
              label: i == 3
                  ? 'Lait concentré sucré en boîte de 397 grammes, format familial'
                  : 'Produit $i',
              value: 900 + i * 350)
      ];
      await pumpComparo(
          t, inScaffold(MarketSlate(title: 'Prix du jour', rows: rows)));
      expect(find.text('Produit 5'), findsNothing);
      expect(find.text('Produit 4'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets('vide', (t) async {
      await pumpComparo(
          t, inScaffold(const MarketSlate(title: 'Prix du jour', rows: [])));
      expect(find.text('Pas encore de prix du jour dans votre zone.'),
          findsOneWidget);
    });
    testWidgets('erreur : Réessayer appelle onRetry', (t) async {
      var retried = 0;
      await pumpComparo(
          t,
          inScaffold(MarketSlate(
              title: 'Prix du jour',
              rows: const [],
              error: true,
              onRetry: () => retried++,
              footer: 'pied')));
      expect(find.text('Prix du jour indisponible.'), findsOneWidget);
      expect(find.text('pied'), findsNothing);
      await t.tap(find.text('Réessayer'));
      expect(retried, 1);
    });
    testWidgets('hors connexion : pied avec la date du cache', (t) async {
      await pumpComparo(
          t,
          inScaffold(const MarketSlate(
              rows: [SlateRow(label: 'Riz', value: 4950)],
              offline: 'prix du 3 nov., 18:40',
              footer: 'ignoré')));
      expect(
          find.text('Hors connexion · prix du 3 nov., 18:40'), findsOneWidget);
    });
    testWidgets('chargement', (t) async {
      await pumpLoading(
          t, const MarketSlate(title: 'Prix du jour', rows: [], loading: true));
      expect(find.byType(Skeleton), findsNWidgets(6));
    });
  });

  group('ListSummary : états', () {
    testWidgets('défaut : total, économie, annonce complète', (t) async {
      var opened = 0;
      await pumpComparo(
          t,
          inScaffold(ListSummary(
              count: 5, best: 13950, save: 800, onOpen: () => opened++)));
      expect(
          find.bySemanticsLabel(
              "Ma liste de la semaine, 5 articles, 13 950 francs au mieux, 800 francs d'économie possible"),
          findsOneWidget);
      await t.tap(find.byType(ListSummary));
      expect(opened, 1);
    });
    testWidgets('vide : invitation à commencer', (t) async {
      await pumpComparo(t, inScaffold(const ListSummary(count: 0)));
      expect(find.text('Commencez votre liste de la semaine'), findsOneWidget);
    });
    testWidgets('hors connexion : pas d’économie promise', (t) async {
      await pumpComparo(
          t,
          inScaffold(const ListSummary(
              count: 5, best: 13950, save: 800, offline: '3 nov., 18:40')));
      expect(find.byType(PriceTag), findsNothing);
      expect(find.text('Hors connexion · totaux du 3 nov., 18:40'),
          findsOneWidget);
    });
    testWidgets('chargement', (t) async {
      await pumpLoading(t, const ListSummary.loading());
      expect(find.byType(Skeleton), findsNWidgets(2));
    });
  });

  group('ProofLine et Picto : états', () {
    testWidgets('ProofLine hors connexion et chargement', (t) async {
      await pumpComparo(
          t,
          inScaffold(const ProofLine(
              level: ProofLevel.high,
              age: 'il y a 3 j',
              source: ProofSource.vendor,
              offline: true)));
      expect(
          find.bySemanticsLabel(
              'Vu il y a 3 j · vendeur vérifié · Fiable · hors connexion'),
          findsOneWidget);
      await pumpLoading(t, const ProofLine.loading());
      expect(find.bySemanticsLabel('Chargement'), findsOneWidget);
    });
    testWidgets('Picto en chargement : vignette seule', (t) async {
      await pumpLoading(t, const ProductPicto.loading(large: true));
      expect(t.getSize(find.byType(Skeleton)), const Size(56, 56));
    });
  });

  testWidgets('animations réduites : le squelette ne pulse pas', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: ComparoTheme.light(),
      home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Skeleton(width: 40))),
    ));
    await t.pumpAndSettle(); // ne termine que si aucune animation ne tourne
    expect(find.byType(Skeleton), findsOneWidget);
  });
}
