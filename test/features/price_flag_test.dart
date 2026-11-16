import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/quality/price_flag.dart';

import '../support/fake_api.dart';

Future<void> _pumpSheet(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [jsonApiProvider.overrideWithValue(api.jsonApi)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: PriceFlagSheet(offerId: 5, merchantName: 'Épicerie démo'),
        ),
      ),
    ),
  );
}

FakeApi _accepting() => FakeApi(
  (request) => (status: 201, body: {'dossier_id': 1, 'created': true}),
);

void main() {
  group('parseSeenAmount', () {
    test('an empty field means no amount', () {
      expect(parseSeenAmount(''), isNull);
      expect(parseSeenAmount('   '), isNull);
    });

    test('reads a whole or decimal amount, with spaces and a comma', () {
      expect(parseSeenAmount('1250'), '1250');
      expect(parseSeenAmount('1 250'), '1250');
      expect(parseSeenAmount('1 250,5'), '1250.5');
      expect(parseSeenAmount('99.90'), '99.90');
    });

    test('refuses what is not an amount, with a message', () {
      for (final text in ['abc', '12,345', '-5', '1e3']) {
        expect(
          () => parseSeenAmount(text),
          throwsA(isA<FormatException>()),
          reason: text,
        );
      }
    });

    test('refuses an amount of zero', () {
      expect(() => parseSeenAmount('0'), throwsFormatException);
    });
  });

  group('the flag sheet', () {
    testWidgets('sends the reason, the price seen and the comment', (
      tester,
    ) async {
      final api = _accepting();
      await _pumpSheet(tester, api);

      await tester.enterText(
        find.widgetWithText(TextField, 'Prix vu en magasin (FCFA), facultatif'),
        '1 000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Un détail à ajouter ? (facultatif)'),
        'Étiquette à 1000',
      );
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/quality/flags/').single.data, {
        'offer_id': 5,
        'reason': 'wrong_amount',
        'observed_amount': '1000',
        'comment': 'Étiquette à 1000',
      });
    });

    testWidgets('another reason sends no price', (tester) async {
      final api = _accepting();
      await _pumpSheet(tester, api);

      await tester.tap(find.text('Produit introuvable ou en rupture'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Prix vu en magasin'), findsNothing);
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      final body = api.sent('POST', 'api/quality/flags/').single.data as Map;
      expect(body['reason'], 'unavailable');
      expect(body.containsKey('observed_amount'), isFalse);
    });

    testWidgets('an invalid price is explained and nothing is sent', (
      tester,
    ) async {
      final api = _accepting();
      await _pumpSheet(tester, api);

      await tester.enterText(
        find.widgetWithText(TextField, 'Prix vu en magasin (FCFA), facultatif'),
        'beaucoup',
      );
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Saisissez un montant'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('a second flag is refused with the API message', (
      tester,
    ) async {
      final api = FakeApi(
        (request) => (
          status: 409,
          body: {
            'detail':
                'Vous avez déjà signalé ce prix : la modération l’examine.',
          },
        ),
      );
      await _pumpSheet(tester, api);

      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Vous avez déjà signalé ce prix'),
        findsOneWidget,
      );
      // The sheet stays open, the user can cancel.
      expect(find.text('Envoyer le signalement'), findsOneWidget);
    });
  });
}
