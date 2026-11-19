import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/space_scaffold.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/models/auth_user.dart';
import 'package:frontend/features/support_agent/support_agent_screens.dart';

import '../support/fake_api.dart';

class _SessionAs extends AuthSessionController {
  _SessionAs(this.roles, this.userId);

  final List<String> roles;
  final int userId;

  @override
  Future<AuthUser?> build() async => AuthUser(
    id: userId,
    email: 'agent@demo.ga',
    displayName: 'Agent',
    emailVerified: true,
    roles: roles,
  );
}

Map<String, Object?> _complaint({
  int id = 3,
  String status = 'filed',
  int? assignedTo,
  int filedBy = 50,
  bool open = true,
  Map<String, Object?>? resolution,
}) => {
  'id': id,
  'complaint_number': 'CMP-0003',
  'complaint_type': 'overcharge',
  'priority': 'high',
  'subject': 'Prix facturé plus haut',
  'description': 'Le ticket montre 1 800 FCFA, on m’a demandé 2 400.',
  'status': status,
  'is_open': open,
  'filed_by': filedBy,
  'assigned_to': assignedTo,
  'against_merchant': 7,
  'merchant_response': '',
  'filed_at': '2026-11-18T09:00:00Z',
  'resolution': resolution,
};

Map<String, Object?> _ticket({
  int id = 8,
  String status = 'open',
  int? assignedTo,
  List<Map<String, Object?>> messages = const [],
}) => {
  'id': id,
  'ticket_number': 'TCK-0008',
  'subject': 'Mon paiement n’apparaît pas',
  'category': 'payment',
  'priority': 'normal',
  'status': status,
  'is_open': status != 'closed',
  'assigned_to': assignedTo,
  'updated_at': '2026-11-18T10:00:00Z',
  'messages': messages,
};

Map<String, Object?> _message(
  String body, {
  String author = 'user',
  bool internal = false,
}) => {
  'body': body,
  'author_type': author,
  'is_internal': internal,
  'author_email': author == 'user' ? 'client@demo.ga' : 'agent@demo.ga',
  'created_at': '2026-11-18T10:00:00Z',
};

Future<FakeApi> _pump(
  WidgetTester tester,
  Widget screen,
  FakeReply Function(RequestOptions request) handler, {
  List<String> roles = const ['consumer', 'support'],
  int userId = 1,
}) async {
  final api = FakeApi((request) {
    // The evidence card of a complaint loads its own list.
    if (request.path.contains('/attachments/')) {
      return ok(const <Object?>[]);
    }
    return handler(request);
  });
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(() => _SessionAs(roles, userId)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

AuthUser _user(List<String> roles) => AuthUser(
  id: 1,
  email: 'x@demo.ga',
  displayName: 'X',
  emailVerified: true,
  roles: roles,
);

void main() {
  group('the support space', () {
    test('opens to the support role and to admins only', () {
      expect(AppSpace.support.isOpenTo(_user(['consumer', 'support'])), isTrue);
      expect(AppSpace.support.isOpenTo(_user(['consumer', 'admin'])), isTrue);
      expect(AppSpace.support.isOpenTo(_user(['consumer'])), isFalse);
      expect(
        AppSpace.support.isOpenTo(_user(['consumer', 'moderator'])),
        isFalse,
      );
      expect(
        AppSpace.support.isOpenTo(_user(['consumer', 'merchant'])),
        isFalse,
      );
    });

    test('is listed among the spaces of an agent, and only theirs', () {
      expect(spacesOf(_user(['consumer', 'support'])), [
        AppSpace.customer,
        AppSpace.support,
      ]);
      expect(spacesOf(_user(['consumer'])), [AppSpace.customer]);
    });

    test('has a tab per work queue', () {
      expect(spaceTabIndex(supportTabs, '/agent/complaints'), 0);
      expect(spaceTabIndex(supportTabs, '/agent/tickets'), 1);
    });
  });

  group('complaints', () {
    testWidgets('lists every complaint with who handles it', (tester) async {
      final api = await _pump(
        tester,
        const Scaffold(body: AgentComplaintsScreen()),
        (_) => ok([
          _complaint(),
          _complaint(id: 4, status: 'under_review', assignedTo: 1),
        ]),
      );

      expect(find.text('Prix facturé plus haut'), findsNWidgets(2));
      expect(find.textContaining('Non assignée'), findsOneWidget);
      expect(find.textContaining('Assignée à vous'), findsOneWidget);
      await tester.tap(find.text('Escaladées'));
      await tester.pumpAndSettle();
      expect(api.calls.last.queryParameters['status'], 'escalated');
    });

    testWidgets('says when there is nothing to handle', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: AgentComplaintsScreen()),
        (_) => ok(const <Object?>[]),
      );
      expect(find.text('Aucune réclamation.'), findsOneWidget);
    });

    testWidgets('an unassigned complaint is taken in charge first', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        const AgentComplaintScreen(complaintId: 3),
        (_) => ok(_complaint()),
      );

      expect(find.text('Trancher'), findsNothing);
      await tester.tap(find.text('Prendre en charge'));
      await tester.pumpAndSettle();
      expect(api.sent('POST', 'api/disputes/3/assign/').single.data, {
        'agent_id': 1,
      });
    });

    testWidgets('a complaint under review can wait for the shop', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        const AgentComplaintScreen(complaintId: 3),
        (_) => ok(_complaint(status: 'under_review', assignedTo: 1)),
      );

      await tester.tap(find.text('Attendre la boutique'));
      await tester.pumpAndSettle();
      expect(
        api.sent('POST', 'api/disputes/3/pending_merchant/'),
        hasLength(1),
      );
    });

    testWidgets('deciding needs an explanation, and a refund needs an amount', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        const AgentComplaintScreen(complaintId: 3),
        (_) => ok(_complaint(status: 'under_review', assignedTo: 1)),
      );

      await tester.tap(find.text('Trancher'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Valider la décision');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.tap(find.text('Excuse formelle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remboursement').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Explication (envoyée au client)'),
        'Le ticket confirme la surfacturation.',
      );
      await tester.pump();
      // The explanation is there but a refund still has no amount.
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Montant'), '600');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/disputes/3/resolve/').single.data, {
        'outcome': 'upheld',
        'remedy_type': 'refund',
        'remedy_amount': '600.0',
        'decision_notes': 'Le ticket confirme la surfacturation.',
      });
    });

    testWidgets('rejecting a complaint grants no remedy and no amount', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        const AgentComplaintScreen(complaintId: 3),
        (_) => ok(_complaint(status: 'under_review', assignedTo: 1)),
      );

      await tester.tap(find.text('Trancher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réclamation fondée'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réclamation non fondée').last);
      await tester.pumpAndSettle();
      expect(find.text('Geste accordé'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Explication (envoyée au client)'),
        'Le prix affiché était bien celui facturé.',
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Valider la décision'),
      );
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/disputes/3/resolve/').single.data, {
        'outcome': 'rejected',
        'remedy_type': 'none',
        'decision_notes': 'Le prix affiché était bien celui facturé.',
      });
    });

    testWidgets('nobody handles their own complaint', (tester) async {
      await _pump(
        tester,
        const AgentComplaintScreen(complaintId: 3),
        (_) => ok(_complaint(filedBy: 1)),
      );

      expect(find.text('Prendre en charge'), findsNothing);
      expect(find.text('Trancher'), findsNothing);
      expect(find.textContaining('propre réclamation'), findsOneWidget);
    });

    testWidgets('a closed complaint shows its decision and offers no action', (
      tester,
    ) async {
      await _pump(
        tester,
        const AgentComplaintScreen(complaintId: 3),
        (_) => ok(
          _complaint(
            status: 'resolved',
            open: false,
            assignedTo: 1,
            resolution: {
              'outcome': 'upheld',
              'decision_notes': 'Remboursement accordé.',
            },
          ),
        ),
      );

      expect(find.text('Réclamation fondée'), findsOneWidget);
      expect(find.text('Remboursement accordé.'), findsOneWidget);
      expect(find.text('Trancher'), findsNothing);
      expect(find.text('Prendre en charge'), findsNothing);
    });

    testWidgets('a customer cannot open a complaint from the support space', (
      tester,
    ) async {
      await _pump(
        tester,
        const AgentComplaintScreen(complaintId: 3),
        (_) => ok(_complaint()),
        roles: const ['consumer'],
      );
      expect(
        find.text('Cet espace est réservé à un autre profil.'),
        findsOneWidget,
      );
      expect(find.text('Prix facturé plus haut'), findsNothing);
    });

    testWidgets('an admin handles complaints too', (tester) async {
      await _pump(
        tester,
        const AgentComplaintScreen(complaintId: 3),
        (_) => ok(_complaint()),
        roles: const ['consumer', 'admin'],
      );
      expect(find.text('Prendre en charge'), findsOneWidget);
    });
  });

  group('help requests', () {
    testWidgets('lists the requests with their status', (tester) async {
      final api = await _pump(
        tester,
        const Scaffold(body: AgentTicketsScreen()),
        (_) => ok([
          _ticket(),
          _ticket(id: 9, status: 'waiting_user', assignedTo: 2),
        ]),
      );

      expect(find.text('Mon paiement n’apparaît pas'), findsNWidgets(2));
      expect(find.textContaining('Assignée à un collègue'), findsOneWidget);
      await tester.tap(find.text('Ouvertes'));
      await tester.pumpAndSettle();
      expect(api.calls.last.queryParameters['status'], 'open');
    });

    testWidgets('shows internal notes apart from the conversation', (
      tester,
    ) async {
      await _pump(
        tester,
        const AgentTicketScreen(ticketId: 8),
        (_) => ok(
          _ticket(
            messages: [
              _message('Mon paiement a échoué.'),
              _message(
                'Vérifier chez Airtel.',
                author: 'agent',
                internal: true,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Mon paiement a échoué.'), findsOneWidget);
      expect(find.text('Vérifier chez Airtel.'), findsOneWidget);
      expect(find.text('NOTE INTERNE'), findsOneWidget);
    });

    testWidgets('a reply goes to the customer unless marked internal', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        const AgentTicketScreen(ticketId: 8),
        (_) => ok(_ticket()),
      );

      await tester.enterText(find.byType(TextField), 'Nous vérifions.');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();
      expect(
        api.sent('POST', 'api/support/tickets/8/reply/').last.data,
        containsPair('is_internal', false),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'À suivre demain.');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();
      expect(api.sent('POST', 'api/support/tickets/8/reply/').last.data, {
        'body': 'À suivre demain.',
        'is_internal': true,
        'waiting_for_user': false,
      });
    });

    testWidgets('a request is taken in charge and marked resolved', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        const AgentTicketScreen(ticketId: 8),
        (_) => ok(_ticket()),
      );

      await tester.tap(find.text('Prendre en charge'));
      await tester.pumpAndSettle();
      expect(api.sent('POST', 'api/support/tickets/8/assign/').single.data, {
        'agent_id': 1,
      });

      await tester.tap(find.text('Marquer résolue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Paiement retrouvé.');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(api.sent('POST', 'api/support/tickets/8/resolve/').single.data, {
        'note': 'Paiement retrouvé.',
      });
    });

    testWidgets('a customer cannot open the agent view of a request', (
      tester,
    ) async {
      await _pump(
        tester,
        const AgentTicketScreen(ticketId: 8),
        (_) => ok(_ticket()),
        roles: const ['consumer'],
      );
      expect(
        find.text('Cet espace est réservé à un autre profil.'),
        findsOneWidget,
      );
    });
  });
}
