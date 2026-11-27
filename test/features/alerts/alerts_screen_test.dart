import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/formatters/price_formatter.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/alerts/alerts_screen.dart';
import 'package:frontend/features/alerts/data/alert_repository.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/models/auth_user.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _page(List<Map<String, Object?>> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

Map<String, Object?> _alert({
  int id = 1,
  String product = 'Riz parfumé',
  String trigger = 'price_drop',
  String status = 'active',
  bool? isActive,
  String? threshold = '1200.00',
  int triggerCount = 0,
}) => {
  'id': id,
  'product': 15,
  'product_name': product,
  'trigger_type': trigger,
  'status': status,
  'is_active': isActive ?? status == 'active',
  'repeat': false,
  'threshold_amount': threshold,
  'threshold_currency': 'XAF',
  'trigger_count': triggerCount,
  'last_triggered_at': null,
};

const _failure = (
  status: 500,
  body: {
    'error': {'code': 'server_error', 'detail': 'Panne.'},
  },
);

/// A session that cannot be known: [error] is what the check fails with.
class _FailingSession extends AuthSessionController {
  _FailingSession(this.error);

  final Object error;
  static int builds = 0;

  @override
  Future<AuthUser?> build() async {
    builds++;
    throw error;
  }
}

/// A session check that never answers.
class _PendingSession extends AuthSessionController {
  @override
  Future<AuthUser?> build() => Completer<AuthUser?>().future;
}

class _Backend {
  _Backend({
    this.alerts = const [],
    this.failList = false,
    this.failWrites = false,
  });

  final List<Map<String, Object?>> alerts;
  final bool failList;
  final bool failWrites;

  FakeReply answer(RequestOptions request) {
    if (request.method == 'GET') {
      return failList ? _failure : ok(_page(alerts));
    }
    if (failWrites) {
      return _failure;
    }
    return ok(_alert());
  }
}

Future<FakeApi> _open(
  WidgetTester tester,
  _Backend backend, {
  AuthSessionController Function()? session,
  bool settle = true,
}) async {
  final api = FakeApi(backend.answer);
  final repository = AlertRepository(
    Dio(BaseOptions(baseUrl: 'https://api.example.test/'))
      ..httpClientAdapter = api,
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AlertsScreen()),
      GoRoute(
        path: '/auth',
        builder: (context, state) =>
            const Scaffold(body: Text('Page de connexion')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      // No automatic retry: a second attempt must come from the user.
      retry: (retryCount, error) => null,
      overrides: [
        alertRepositoryProvider.overrideWithValue(repository),
        authSessionProvider.overrideWith(session ?? SignedInSession.new),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return api;
}

void main() {
  group('the session', () {
    testWidgets('invites a visitor to sign in', (tester) async {
      await _open(tester, _Backend(), session: VisitorSession.new);

      expect(
        find.text('Connectez-vous pour retrouver vos alertes.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Se connecter ou créer un compte'));
      await tester.pumpAndSettle();

      expect(find.text('Page de connexion'), findsOneWidget);
    });

    testWidgets('the account button goes to the sign-in page', (tester) async {
      await _open(tester, _Backend());

      await tester.tap(find.byTooltip('Compte'));
      await tester.pumpAndSettle();

      expect(find.text('Page de connexion'), findsOneWidget);
    });

    testWidgets('waits while the account is being checked', (tester) async {
      await _open(
        tester,
        _Backend(),
        session: _PendingSession.new,
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('an unknown failure asks to retry', (tester) async {
      _FailingSession.builds = 0;
      await _open(
        tester,
        _Backend(),
        session: () => _FailingSession(Exception('boom')),
      );

      expect(find.text('Impossible de vérifier votre compte.'), findsOneWidget);
      expect(_FailingSession.builds, 1);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(_FailingSession.builds, 2);
    });

    testWidgets('a server failure shows its own message', (tester) async {
      await _open(
        tester,
        _Backend(),
        session: () => _FailingSession(
          const ApiException(
            kind: ApiErrorKind.http,
            statusCode: 503,
            detail: 'Maintenance en cours.',
          ),
        ),
      );

      expect(find.text('Maintenance en cours.'), findsOneWidget);
    });
  });

  group('the alert list', () {
    testWidgets('waits for the alerts', (tester) async {
      await _open(tester, _Backend(), settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('explains how to follow a price when there is none', (
      tester,
    ) async {
      await _open(tester, _Backend());

      expect(find.text('Aucune alerte pour le moment.'), findsOneWidget);
      expect(
        find.text('Ouvrez une fiche produit et choisissez « Suivre le prix ».'),
        findsOneWidget,
      );
    });

    testWidgets('shows the server error and reloads on retry', (tester) async {
      final api = await _open(tester, _Backend(failList: true));

      expect(find.text('Panne.'), findsOneWidget);
      final before = api.sent('GET', 'api/alerts/').length;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(api.sent('GET', 'api/alerts/').length, greaterThan(before));
    });

    testWidgets('can be pulled to refresh', (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = await _open(tester, _Backend(alerts: [_alert()]));
      final before = api.sent('GET', 'api/alerts/').length;

      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(api.sent('GET', 'api/alerts/').length, greaterThan(before));
    });
  });

  group('an alert card', () {
    testWidgets('says what it watches, its threshold and its state', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(alerts: [_alert(triggerCount: 3, status: 'paused')]),
      );

      expect(find.text('Riz parfumé'), findsOneWidget);
      expect(find.text('Baisse de prix sous le seuil'), findsOneWidget);
      expect(
        find.text('Seuil : ${formatPrice('1200.00', 'XAF')}'),
        findsOneWidget,
      );
      expect(find.text('En pause · 3 déclenchement(s)'), findsOneWidget);
    });

    testWidgets('names every kind of trigger, even an unknown one', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(
        tester,
        _Backend(
          alerts: [
            _alert(id: 1, trigger: 'price_target'),
            _alert(id: 2, trigger: 'back_in_stock', threshold: null),
            _alert(id: 3, trigger: 'new_offer', threshold: null),
            _alert(id: 4, trigger: 'price_change', threshold: null),
            _alert(id: 5, trigger: 'stock_low', threshold: null),
          ],
        ),
      );

      expect(find.text('Prix cible atteint'), findsOneWidget);
      expect(find.text('Retour en stock'), findsOneWidget);
      expect(find.text('Nouvelle offre disponible'), findsOneWidget);
      expect(find.text('Tout changement de prix'), findsOneWidget);
      expect(find.text('stock low'), findsOneWidget);
      // Only the two alerts with a threshold show one.
      expect(find.textContaining('Seuil :'), findsOneWidget);
    });

    testWidgets('names every state', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(
        tester,
        _Backend(
          alerts: [
            _alert(id: 1, status: 'active'),
            _alert(id: 2, status: 'triggered'),
            _alert(id: 3, status: 'expired'),
            _alert(id: 4, status: 'cancelled'),
            _alert(id: 5, status: 'archived'),
          ],
        ),
      );

      for (final label in [
        'Active',
        'Déclenchée',
        'Expirée',
        'Annulée',
        'archived',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('only offers the actions that still make sense', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(
        tester,
        _Backend(
          alerts: [
            _alert(id: 1, status: 'active'),
            _alert(id: 2, status: 'paused', isActive: false),
            _alert(id: 3, status: 'triggered'),
            _alert(id: 4, status: 'expired'),
            _alert(id: 5, status: 'cancelled'),
          ],
        ),
      );

      expect(find.byTooltip('Mettre en pause'), findsOneWidget);
      expect(find.byTooltip('Reprendre'), findsOneWidget);
      // Active, paused and triggered can still be cancelled.
      expect(find.byTooltip('Annuler l’alerte'), findsNWidgets(3));
    });
  });

  group('acting on an alert', () {
    testWidgets('pauses an active alert', (tester) async {
      final api = await _open(tester, _Backend(alerts: [_alert()]));

      await tester.tap(find.byTooltip('Mettre en pause'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/alerts/1/pause/'), hasLength(1));
    });

    testWidgets('resumes a paused alert', (tester) async {
      final api = await _open(
        tester,
        _Backend(alerts: [_alert(status: 'paused', isActive: false)]),
      );

      await tester.tap(find.byTooltip('Reprendre'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/alerts/1/resume/'), hasLength(1));
    });

    testWidgets('shows the error when pausing fails', (tester) async {
      final api = await _open(
        tester,
        _Backend(alerts: [_alert()], failWrites: true),
      );

      await tester.tap(find.byTooltip('Mettre en pause'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/alerts/1/pause/'), hasLength(1));
      expect(find.text('Panne.'), findsOneWidget);
    });

    testWidgets('cancels an alert after a confirmation', (tester) async {
      final api = await _open(tester, _Backend(alerts: [_alert()]));

      await tester.tap(find.byTooltip('Annuler l’alerte'));
      await tester.pumpAndSettle();
      expect(find.text('Annuler cette alerte ?'), findsOneWidget);
      expect(
        find.text('L’alerte pour « Riz parfumé » sera arrêtée.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Annuler l’alerte'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/alerts/1/'), hasLength(1));
    });

    testWidgets('keeps the alert when the user goes back', (tester) async {
      final api = await _open(tester, _Backend(alerts: [_alert()]));

      await tester.tap(find.byTooltip('Annuler l’alerte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garder'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/alerts/1/'), isEmpty);
    });

    testWidgets('shows the error when cancelling fails', (tester) async {
      final api = await _open(
        tester,
        _Backend(alerts: [_alert()], failWrites: true),
      );

      await tester.tap(find.byTooltip('Annuler l’alerte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler l’alerte'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/alerts/1/'), hasLength(1));
      expect(find.text('Panne.'), findsOneWidget);
    });
  });
}
