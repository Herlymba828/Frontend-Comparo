import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/formatters/price_formatter.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/account/account_repository.dart';
import 'package:frontend/features/moderation/moderation_review_screens.dart';
import 'package:frontend/features/moderation/moderation_screen.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _page(List<Map<String, Object?>> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

Map<String, Object?> _report({
  int id = 1,
  String product = 'Riz parfumé',
  int confirmations = 2,
  int rejections = 0,
  int required = 2,
  String status = 'pending',
  String rejectionReason = '',
  bool photo = false,
  bool outlier = false,
  bool displayError = false,
  String alias = 'Panda-12',
}) => {
  'id': id,
  'raw_product_name': product,
  'observed_price': '950.00',
  'currency': 'XAF',
  'quantity': '1',
  'unit_symbol': 'kg',
  'location': 'Marché Mont-Bouët',
  'status': status,
  'observed_at': '2026-11-20T10:30:00Z',
  'confirmations_count': confirmations,
  'rejections_count': rejections,
  'required_confirmations': required,
  'rejection_reason': rejectionReason,
  'contributor_alias': alias,
  'has_photo': photo,
  'photo': photo ? 'api/contributions/$id/photo/' : '',
  'is_price_outlier': outlier,
  'display_error': displayError,
};

Map<String, Object?> _anomaly({
  int id = 1,
  String status = 'open',
  String severity = 'high',
  String type = 'price_spike',
  String min = '500.00',
  String max = '2000.00',
  String ratio = '3.5000',
  String notes = '',
}) => {
  'id': id,
  'product_name': 'Huile 1 L',
  'merchant_name': 'Boutique Centre',
  'anomaly_type': type,
  'severity': severity,
  'status': status,
  'expected_range_min': min,
  'expected_range_max': max,
  'deviation_ratio': ratio,
  'notes': notes,
  'detected_at': '2026-11-05T08:00:00Z',
};

class _Backend {
  _Backend({
    this.queue = const [],
    this.decided = const [],
    this.anomalies = const [],
    this.fail = const {},
    this.missing = const {},
  });

  final List<Map<String, Object?>> queue;
  final List<Map<String, Object?>> decided;
  final List<Map<String, Object?>> anomalies;
  final Map<String, String> fail;

  /// Calls that find nothing (404, as a file download does).
  final Set<String> missing;

  FakeReply answer(RequestOptions request) {
    final key = '${request.method} ${request.path}';
    if (missing.contains(key)) {
      return (status: 404, body: <String, Object?>{});
    }
    final refusal = fail[key];
    if (refusal != null) {
      return (
        status: 400,
        body: {
          'error': {'code': 'refused', 'detail': refusal},
        },
      );
    }
    if (key == 'GET api/contributions/') {
      final query = request.queryParameters;
      return ok(_page(query.containsKey('to_review') ? queue : decided));
    }
    if (key == 'GET api/quality/anomalies/') {
      return ok(_page(anomalies));
    }
    return ok(<String, Object?>{});
  }
}

Future<FakeApi> _open(
  WidgetTester tester,
  _Backend backend,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeApi(backend.answer);
  await tester.pumpWidget(
    ProviderScope(
      // No automatic retry: a second attempt must come from the user.
      retry: (retryCount, error) => null,
      overrides: [jsonApiProvider.overrideWithValue(api.jsonApi)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Contribution _contribution(int confirmations, int rejections, int required) =>
    Contribution.fromJson(
      _report(
        confirmations: confirmations,
        rejections: rejections,
        required: required,
      ),
    );

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group('when a report may be published', () {
    test('it needs enough confirmations', () {
      expect(isReadyToPublish(_contribution(2, 0, 2)), isTrue);
      expect(isReadyToPublish(_contribution(1, 0, 2)), isFalse);
    });

    test('and more confirmations than contestations', () {
      expect(isReadyToPublish(_contribution(3, 1, 2)), isTrue);
      expect(isReadyToPublish(_contribution(2, 2, 2)), isFalse);
      expect(isReadyToPublish(_contribution(2, 3, 2)), isFalse);
    });
  });

  group('the queue', () {
    testWidgets('says when nothing waits for a decision', (tester) async {
      await _open(tester, _Backend(), const ModerationQueueScreen());

      expect(find.text('Aucun relevé en attente de décision.'), findsOneWidget);
    });

    testWidgets('shows each report as the moderator examines it', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(
          queue: [_report(outlier: true, displayError: true, rejections: 1)],
        ),
        const ModerationQueueScreen(),
      );

      expect(find.text('Riz parfumé'), findsOneWidget);
      expect(find.text(formatPrice('950.00', 'XAF')), findsOneWidget);
      expect(
        find.textContaining('Marché Mont-Bouët · relevé le'),
        findsOneWidget,
      );
      expect(find.textContaining('par Panda-12'), findsOneWidget);
      expect(
        find.text('Confirmations : 2 / 2 · contestations : 1'),
        findsOneWidget,
      );
      expect(find.text('PRIX INHABITUEL'), findsOneWidget);
      expect(find.text('ERREUR D’AFFICHAGE'), findsOneWidget);
      expect(find.text('Voir la photo'), findsNothing);
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final api = await _open(
        tester,
        _Backend(queue: [_report()]),
        const ModerationQueueScreen(),
      );
      final before = api.sent('GET', 'api/contributions/').length;

      await _pullToRefresh(tester);

      expect(api.sent('GET', 'api/contributions/').length, greaterThan(before));
    });

    testWidgets('shows why it could not be loaded and can be retried', (
      tester,
    ) async {
      final api = await _open(
        tester,
        _Backend(fail: {'GET api/contributions/': 'File indisponible.'}),
        const ModerationQueueScreen(),
      );

      expect(find.text('File indisponible.'), findsOneWidget);
      final before = api.sent('GET', 'api/contributions/').length;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(api.sent('GET', 'api/contributions/').length, greaterThan(before));
    });

    testWidgets('a report with a photo can show it, or say why not', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(
          queue: [_report(photo: true)],
          missing: {'GET api/contributions/1/photo/'},
        ),
        const ModerationQueueScreen(),
      );

      await tester.tap(find.text('Voir la photo'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cet élément est introuvable ou n’existe plus.'),
        findsOneWidget,
      );
    });
  });

  group('deciding on a report', () {
    testWidgets('publishing is possible once it is confirmed enough', (
      tester,
    ) async {
      final api = await _open(
        tester,
        _Backend(queue: [_report()]),
        const ModerationQueueScreen(),
      );
      final before = api.sent('GET', 'api/contributions/').length;

      await tester.tap(find.text('Publier le prix'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/contributions/1/review/').single.data, {
        'decision': 'accepted',
        'reason': '',
      });
      expect(find.text('Prix publié.'), findsOneWidget);
      // The queue moves on.
      expect(api.sent('GET', 'api/contributions/').length, greaterThan(before));
    });

    testWidgets('publishing is refused while it lacks confirmations', (
      tester,
    ) async {
      final api = await _open(
        tester,
        _Backend(queue: [_report(confirmations: 1)]),
        const ModerationQueueScreen(),
      );

      await tester.tap(find.text('Publier le prix'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/contributions/1/review/'), isEmpty);
    });

    testWidgets('a refusal carries the reason given to the contributor', (
      tester,
    ) async {
      final api = await _open(
        tester,
        _Backend(queue: [_report()]),
        const ModerationQueueScreen(),
      );

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      expect(find.text('Refuser le relevé'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Photo floue');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/contributions/1/review/').single.data, {
        'decision': 'rejected',
        'reason': 'Photo floue',
      });
      expect(find.text('Décision enregistrée.'), findsOneWidget);
    });

    testWidgets('a refusal without a reason is not sent', (tester) async {
      final api = await _open(
        tester,
        _Backend(queue: [_report()]),
        const ModerationQueueScreen(),
      );

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(find.text('Indiquez un motif.'), findsOneWidget);
      expect(api.sent('POST', 'api/contributions/1/review/'), isEmpty);
    });

    testWidgets('a duplicate is marked with its own title', (tester) async {
      final api = await _open(
        tester,
        _Backend(queue: [_report()]),
        const ModerationQueueScreen(),
      );

      await tester.tap(find.text('Doublon'));
      await tester.pumpAndSettle();
      expect(find.text('Marquer comme doublon'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Déjà relevé ce matin');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(
        (api.sent('POST', 'api/contributions/1/review/').single.data
            as Map)['decision'],
        'duplicate',
      );
    });

    testWidgets('a cancelled reason sends nothing', (tester) async {
      final api = await _open(
        tester,
        _Backend(queue: [_report()]),
        const ModerationQueueScreen(),
      );

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/contributions/1/review/'), isEmpty);
    });

    testWidgets('a decision refused by the server shows why', (tester) async {
      final api = await _open(
        tester,
        _Backend(
          queue: [_report()],
          fail: {'POST api/contributions/1/review/': 'Déjà décidé.'},
        ),
        const ModerationQueueScreen(),
      );
      final before = api.sent('GET', 'api/contributions/').length;

      await tester.tap(find.text('Publier le prix'));
      await tester.pumpAndSettle();

      expect(find.text('Déjà décidé.'), findsOneWidget);
      // Decided by someone else meanwhile: the queue reloads all the same.
      expect(api.sent('GET', 'api/contributions/').length, greaterThan(before));
    });
  });

  group('the decisions', () {
    testWidgets('say when the moderator has decided nothing yet', (
      tester,
    ) async {
      await _open(tester, _Backend(), const ModerationDecisionsScreen());

      expect(
        find.text('Vous n’avez encore décidé aucun relevé.'),
        findsOneWidget,
      );
    });

    testWidgets('show the outcome and the reason, without actions', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(
          decided: [
            _report(status: 'rejected', rejectionReason: 'Photo floue'),
          ],
        ),
        const ModerationDecisionsScreen(),
      );

      expect(find.text('Motif : Photo floue'), findsOneWidget);
      expect(find.text('Publier le prix'), findsNothing);
      expect(find.text('Refuser'), findsNothing);
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final api = await _open(
        tester,
        _Backend(decided: [_report(status: 'accepted')]),
        const ModerationDecisionsScreen(),
      );
      final before = api.sent('GET', 'api/contributions/').length;

      await _pullToRefresh(tester);

      expect(api.sent('GET', 'api/contributions/').length, greaterThan(before));
    });

    testWidgets('show why they could not be loaded', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'GET api/contributions/': 'Historique indisponible.'}),
        const ModerationDecisionsScreen(),
      );

      expect(find.text('Historique indisponible.'), findsOneWidget);
    });
  });

  group('the anomalies', () {
    testWidgets('say when there is nothing to examine', (tester) async {
      await _open(tester, _Backend(), const ModerationAnomaliesScreen());

      expect(find.text('Aucune anomalie à examiner.'), findsOneWidget);
    });

    testWidgets('list only the open ones, with their expected range', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(
          anomalies: [
            _anomaly(notes: 'Vu sur trois relevés.'),
            _anomaly(id: 2, status: 'dismissed'),
            _anomaly(id: 3, status: 'under_review', severity: 'low'),
          ],
        ),
        const ModerationAnomaliesScreen(),
      );

      expect(find.text('Huile 1 L'), findsNWidgets(2));
      expect(find.text('ÉLEVÉE'), findsOneWidget);
      expect(find.text('FAIBLE'), findsOneWidget);
      expect(
        find.textContaining('Pic de prix · Boutique Centre'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining(
          'Attendu entre ${formatPrice('500.00', 'XAF')} '
          'et ${formatPrice('2000.00', 'XAF')} (écart ×3.5000)',
        ),
        findsNWidgets(2),
      );
      expect(find.text('Vu sur trois relevés.'), findsOneWidget);
    });

    testWidgets('an anomaly without a range shows none', (tester) async {
      await _open(
        tester,
        _Backend(
          anomalies: [_anomaly(min: '', max: '', ratio: '')],
        ),
        const ModerationAnomaliesScreen(),
      );

      expect(find.textContaining('Attendu entre'), findsNothing);
    });

    testWidgets('an unknown type is shown as the server names it', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(
          anomalies: [_anomaly(type: 'gremlin', severity: 'critical')],
        ),
        const ModerationAnomaliesScreen(),
      );

      expect(find.textContaining('gremlin · Boutique Centre'), findsOneWidget);
      expect(find.text('CRITIQUE'), findsOneWidget);
    });

    testWidgets('keeping the price sends the note and keeps the price', (
      tester,
    ) async {
      final api = await _open(
        tester,
        _Backend(anomalies: [_anomaly()]),
        const ModerationAnomaliesScreen(),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Garder le prix'));
      await tester.pumpAndSettle();
      expect(find.text('Pourquoi ce prix est juste'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Promotion confirmée ');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/quality/anomalies/1/dismiss/').single.data, {
        'notes': 'Promotion confirmée',
      });
      expect(find.text('Prix conservé.'), findsOneWidget);
    });

    testWidgets('suspending the price removes it from the comparison', (
      tester,
    ) async {
      final api = await _open(
        tester,
        _Backend(anomalies: [_anomaly()]),
        const ModerationAnomaliesScreen(),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Suspendre le prix'));
      await tester.pumpAndSettle();
      expect(find.text('Pourquoi ce prix est faux'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Erreur de saisie');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/quality/anomalies/1/resolve/').single.data, {
        'notes': 'Erreur de saisie',
        'suspend_price': true,
      });
      expect(find.text('Prix retiré de la comparaison.'), findsOneWidget);
    });

    testWidgets('a cancelled note sends nothing', (tester) async {
      final api = await _open(
        tester,
        _Backend(anomalies: [_anomaly()]),
        const ModerationAnomaliesScreen(),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Suspendre le prix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/quality/anomalies/1/resolve/'), isEmpty);
    });

    testWidgets('a refusal shows why and reloads the list', (tester) async {
      final api = await _open(
        tester,
        _Backend(
          anomalies: [_anomaly()],
          fail: {'POST api/quality/anomalies/1/dismiss/': 'Déjà traitée.'},
        ),
        const ModerationAnomaliesScreen(),
      );
      final before = api.sent('GET', 'api/quality/anomalies/').length;

      await tester.tap(find.widgetWithText(OutlinedButton, 'Garder le prix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(find.text('Déjà traitée.'), findsOneWidget);
      expect(
        api.sent('GET', 'api/quality/anomalies/').length,
        greaterThan(before),
      );
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final api = await _open(
        tester,
        _Backend(anomalies: [_anomaly()]),
        const ModerationAnomaliesScreen(),
      );
      final before = api.sent('GET', 'api/quality/anomalies/').length;

      await _pullToRefresh(tester);

      expect(
        api.sent('GET', 'api/quality/anomalies/').length,
        greaterThan(before),
      );
    });

    testWidgets('show why they could not be loaded', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'GET api/quality/anomalies/': 'Qualité indisponible.'}),
        const ModerationAnomaliesScreen(),
      );

      expect(find.text('Qualité indisponible.'), findsOneWidget);
    });
  });

  group('the note dialog', () {
    Future<String?> ask(
      WidgetTester tester, {
      required bool mustFill,
      required String typed,
    }) async {
      String? answer;
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  answer = await askNote(
                    context,
                    title: 'Note',
                    label: 'Pourquoi',
                    required: mustFill,
                  );
                  finished = true;
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), typed);
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      return answer;
    }

    testWidgets('gives the trimmed note', (tester) async {
      expect(await ask(tester, mustFill: false, typed: '  ok '), 'ok');
    });

    testWidgets('accepts an empty note when it is optional', (tester) async {
      expect(await ask(tester, mustFill: false, typed: ''), '');
    });

    testWidgets('refuses an empty note when it is required', (tester) async {
      expect(await ask(tester, mustFill: true, typed: ''), isNull);
      expect(find.text('Indiquez un motif.'), findsOneWidget);
    });
  });
}
