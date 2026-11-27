import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/account/support_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _page(List<Map<String, Object?>> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

Map<String, Object?> _ticket({
  int id = 1,
  String subject = 'Colis en retard',
  String status = 'open',
  bool isOpen = true,
  bool withMessages = true,
}) => {
  'id': id,
  'ticket_number': 'TCK-00$id',
  'subject': subject,
  'category': 'payment',
  'status': status,
  'is_open': isOpen,
  'updated_at': '2026-11-20T10:30:00Z',
  'messages': withMessages
      ? [
          {
            'body': 'Où est mon colis ?',
            'author_type': 'user',
            'created_at': '2026-11-20T09:00:00Z',
          },
          {
            'body': 'Nous vérifions auprès du livreur.',
            'author_type': 'support',
            'created_at': '2026-11-20T10:00:00Z',
          },
        ]
      : <Object?>[],
};

Map<String, Object?> _complaint() => {
  'id': 4,
  'complaint_number': 'CPL-004',
  'subject': 'Prix affiché différent',
  'complaint_type': 'wrong_price',
  'status': 'filed',
  'filed_at': '2026-11-19T08:00:00Z',
  'is_open': true,
};

const _error500 = (
  status: 500,
  body: {
    'error': {'code': 'server_error', 'detail': 'Panne.'},
  },
);

final _ticketDetail = RegExp(r'^api/support/tickets/(\d+)/$');

/// What the API holds for a test, and what it answers.
class _Backend {
  _Backend({
    this.tickets = const [],
    this.complaints = const [],
    this.detail,
    this.failWrites = false,
  });

  final List<Map<String, Object?>> tickets;
  final List<Map<String, Object?>> complaints;
  final Map<String, Object?>? detail;
  final bool failWrites;

  FakeReply answer(RequestOptions request) {
    final path = request.path;
    final isWrite = request.method == 'POST';
    if (isWrite && failWrites) {
      return _error500;
    }
    if (path == 'api/support/tickets/') {
      return isWrite
          ? ok(_ticket(id: 9, subject: 'Nouvelle', withMessages: false))
          : ok(_page(tickets));
    }
    if (path == 'api/disputes/') {
      return isWrite ? ok(<String, Object?>{}) : ok(_page(complaints));
    }
    if (_ticketDetail.hasMatch(path) && !isWrite) {
      return ok(detail ?? _ticket(withMessages: false));
    }
    return ok(<String, Object?>{});
  }
}

Future<FakeApi> _open(
  WidgetTester tester,
  _Backend backend, {
  String? orderNumber,
  bool visitor = false,
  Widget Function()? home,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeApi(backend.answer);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            home?.call() ?? SupportScreen(orderNumber: orderNumber),
      ),
      GoRoute(
        path: '/support/tickets/:id',
        builder: (context, state) =>
            TicketScreen(ticketId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/support/complaints/:id',
        builder: (context, state) =>
            const Scaffold(body: Text('Fiche de la réclamation')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(
          visitor ? VisitorSession.new : SignedInSession.new,
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<FakeApi> _openTicket(WidgetTester tester, _Backend backend) =>
    _open(tester, backend, home: () => const TicketScreen(ticketId: 1));

Finder _textField(String label) => find.widgetWithText(TextField, label);

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('the tickets tab', () {
    testWidgets('invites a visitor to sign in', (tester) async {
      await _open(tester, _Backend(), visitor: true);

      expect(
        find.text('Connectez-vous pour accéder à cet espace.'),
        findsOneWidget,
      );
    });

    testWidgets('says so when there is no request yet', (tester) async {
      await _open(tester, _Backend());

      expect(find.text('Aucune demande d’aide.'), findsOneWidget);
    });

    testWidgets('lists the requests and opens one', (tester) async {
      await _open(tester, _Backend(tickets: [_ticket()]));

      expect(find.text('Colis en retard'), findsOneWidget);
      expect(find.textContaining('TCK-001 · Paiement'), findsOneWidget);
      expect(find.textContaining('Mis à jour le'), findsOneWidget);

      await tester.tap(find.text('Colis en retard'));
      await tester.pumpAndSettle();

      expect(find.text('Ma demande'), findsOneWidget);
    });

    testWidgets('can be refreshed by pulling', (tester) async {
      final api = await _open(tester, _Backend(tickets: [_ticket()]));
      final before = api.sent('GET', 'api/support/tickets/').length;

      // The threshold is a share of the height of the (tall) test window.
      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        api.sent('GET', 'api/support/tickets/').length,
        greaterThan(before),
      );
    });
  });

  group('a new request', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Nouvelle demande'));
      await tester.pumpAndSettle();
    }

    testWidgets('needs a title and a message', (tester) async {
      final api = await _open(tester, _Backend());
      await openDialog(tester);

      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(find.text('Indiquez un titre et un message.'), findsOneWidget);
      expect(api.sent('POST', 'api/support/tickets/'), isEmpty);
    });

    testWidgets('is sent with its subject, then opened', (tester) async {
      final api = await _open(tester, _Backend());
      await openDialog(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paiement').last);
      await tester.pumpAndSettle();
      await tester.enterText(_textField('Titre'), '  Débit en double ');
      await tester.enterText(
        _textField('Votre message'),
        ' Prélevé deux fois ',
      );
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      final sent = api.sent('POST', 'api/support/tickets/');
      expect(sent, hasLength(1));
      expect(sent.single.data, {
        'subject': 'Débit en double',
        'body': 'Prélevé deux fois',
        'category': 'payment',
      });
      expect(find.text('Ma demande'), findsOneWidget);
    });

    testWidgets('about an order starts with that order', (tester) async {
      final api = await _open(tester, _Backend(), orderNumber: 'CMD-17');
      await openDialog(tester);

      expect(find.text('Commande CMD-17'), findsOneWidget);
      await tester.enterText(
        _textField('Votre message'),
        'Il manque un article',
      );
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      final data = api.sent('POST', 'api/support/tickets/').single.data as Map;
      expect(data['category'], 'order');
      expect(data['subject'], 'Commande CMD-17');
    });

    testWidgets('stays open when the server refuses it', (tester) async {
      final api = await _open(tester, _Backend(failWrites: true));
      await openDialog(tester);
      await tester.enterText(_textField('Titre'), 'Aide');
      await tester.enterText(_textField('Votre message'), 'Bonjour');

      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(api.sent('POST', 'api/support/tickets/'), hasLength(1));
    });

    testWidgets('can be cancelled', (tester) async {
      final api = await _open(tester, _Backend());
      await openDialog(tester);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(api.sent('POST', 'api/support/tickets/'), isEmpty);
    });
  });

  group('an open request', () {
    testWidgets('shows the conversation, each message by its author', (
      tester,
    ) async {
      await _openTicket(tester, _Backend(detail: _ticket()));

      expect(find.text('TCK-001'), findsOneWidget);
      expect(find.text('Où est mon colis ?'), findsOneWidget);
      expect(find.text('Nous vérifions auprès du livreur.'), findsOneWidget);
      expect(find.textContaining('Vous · '), findsOneWidget);
      expect(find.textContaining('Support · '), findsOneWidget);
    });

    testWidgets('sends a reply and clears the field', (tester) async {
      final api = await _openTicket(tester, _Backend(detail: _ticket()));

      await tester.enterText(_textField('Votre réponse…'), '  Merci  ');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();

      final sent = api.sent('POST', 'api/support/tickets/1/reply/');
      expect(sent.single.data, {'body': 'Merci'});
      expect(
        tester.widget<TextField>(_textField('Votre réponse…')).controller!.text,
        isEmpty,
      );
    });

    testWidgets('does not send an empty reply', (tester) async {
      final api = await _openTicket(tester, _Backend(detail: _ticket()));

      await tester.enterText(_textField('Votre réponse…'), '   ');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/support/tickets/1/reply/'), isEmpty);
    });

    testWidgets('is closed with a satisfaction score', (tester) async {
      final api = await _openTicket(tester, _Backend(detail: _ticket()));

      await tester.tap(find.byTooltip('Clore la demande'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('★★★★'));
      await tester.pumpAndSettle();

      final sent = api.sent('POST', 'api/support/tickets/1/close/');
      expect(sent.single.data, {'satisfaction_score': 4});
    });

    testWidgets('shows the error when the reply fails', (tester) async {
      final api = await _openTicket(
        tester,
        _Backend(detail: _ticket(), failWrites: true),
      );

      await tester.enterText(_textField('Votre réponse…'), 'Bonjour');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/support/tickets/1/reply/'), hasLength(1));
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('a finished request', () {
    testWidgets('can be reopened', (tester) async {
      final api = await _openTicket(
        tester,
        _Backend(detail: _ticket(status: 'closed', isOpen: false)),
      );

      expect(find.byTooltip('Envoyer'), findsNothing);
      expect(find.text('Clore et noter'), findsNothing);
      await tester.tap(find.text('Rouvrir'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/support/tickets/1/reopen/'), hasLength(1));
    });

    testWidgets('a resolved one can be closed and rated', (tester) async {
      final api = await _openTicket(
        tester,
        _Backend(detail: _ticket(status: 'resolved', isOpen: false)),
      );

      await tester.tap(find.text('Clore et noter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('★★★★★'));
      await tester.pumpAndSettle();

      final sent = api.sent('POST', 'api/support/tickets/1/close/');
      expect(sent.single.data, {'satisfaction_score': 5});
    });
  });

  group('the complaints tab', () {
    testWidgets('says so when there is none', (tester) async {
      await _open(tester, _Backend());
      await _tapTab(tester, 'Réclamations');

      expect(find.text('Aucune réclamation.'), findsOneWidget);
    });

    testWidgets('lists the complaints and opens one', (tester) async {
      await _open(tester, _Backend(complaints: [_complaint()]));
      await _tapTab(tester, 'Réclamations');

      expect(find.text('Prix affiché différent'), findsOneWidget);
      expect(
        find.textContaining('CPL-004 · Prix incorrect ou trompeur'),
        findsOneWidget,
      );

      await tester.tap(find.text('Prix affiché différent'));
      await tester.pumpAndSettle();

      expect(find.text('Fiche de la réclamation'), findsOneWidget);
    });

    testWidgets('needs a title and a description', (tester) async {
      final api = await _open(tester, _Backend());
      await _tapTab(tester, 'Réclamations');
      await tester.tap(find.text('Déposer une réclamation'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Déposer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Indiquez un titre et une description.'),
        findsOneWidget,
      );
      expect(api.sent('POST', 'api/disputes/'), isEmpty);
    });

    testWidgets('is filed with its type, then the list is reloaded', (
      tester,
    ) async {
      final api = await _open(tester, _Backend());
      await _tapTab(tester, 'Réclamations');
      final before = api.sent('GET', 'api/disputes/').length;
      await tester.tap(find.text('Déposer une réclamation'));
      await tester.pumpAndSettle();

      await tester.enterText(_textField('Titre'), 'Colis jamais reçu');
      await tester.enterText(
        _textField('Que s’est-il passé ? (commande, date, marchand…)'),
        'Commande du 10/11, rien reçu.',
      );
      await tester.tap(find.text('Déposer'));
      await tester.pumpAndSettle();

      final sent = api.sent('POST', 'api/disputes/');
      expect(sent.single.data, {
        'complaint_type': 'wrong_price',
        'subject': 'Colis jamais reçu',
        'description': 'Commande du 10/11, rien reçu.',
      });
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.sent('GET', 'api/disputes/').length, greaterThan(before));
    });

    testWidgets('stays open when the server refuses it', (tester) async {
      final api = await _open(tester, _Backend(failWrites: true));
      await _tapTab(tester, 'Réclamations');
      await tester.tap(find.text('Déposer une réclamation'));
      await tester.pumpAndSettle();
      await tester.enterText(_textField('Titre'), 'Problème');
      await tester.enterText(
        _textField('Que s’est-il passé ? (commande, date, marchand…)'),
        'Détails',
      );

      await tester.tap(find.text('Déposer'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(api.sent('POST', 'api/disputes/'), hasLength(1));
    });

    testWidgets('the type can be changed before filing', (tester) async {
      final api = await _open(tester, _Backend());
      await _tapTab(tester, 'Réclamations');
      await tester.tap(find.text('Déposer une réclamation'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commande non livrée').last);
      await tester.pumpAndSettle();
      await tester.enterText(_textField('Titre'), 'Rien reçu');
      await tester.enterText(
        _textField('Que s’est-il passé ? (commande, date, marchand…)'),
        'Détails',
      );
      await tester.tap(find.text('Déposer'));
      await tester.pumpAndSettle();

      final data = api.sent('POST', 'api/disputes/').single.data as Map;
      expect(data['complaint_type'], 'non_delivery');
    });
  });
}
