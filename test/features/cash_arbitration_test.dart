import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/models/auth_user.dart';
import 'package:frontend/features/support_agent/support_agent_screens.dart';

import '../support/fake_api.dart';

class _Agent extends AuthSessionController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    id: 1,
    email: 'agent@demo.ga',
    displayName: 'Agent',
    emailVerified: true,
    roles: ['consumer', 'support'],
  );
}

Map<String, Object?> _cashComplaint({
  String status = 'under_review',
  int filedBy = 50,
  Map<String, Object?>? cash,
}) => {
  'id': 9,
  'complaint_number': 'CPL-0009',
  'complaint_type': 'cash_dispute',
  'priority': 'high',
  'subject': 'Espèces à la remise : commande ORD-1',
  'description': 'Le livreur déclare ne pas avoir reçu l’argent.',
  'status': status,
  'is_open': status != 'resolved',
  'filed_by': filedBy,
  'assigned_to': 1,
  'merchant_response': '',
  'filed_at': '2026-11-21T09:00:00Z',
  'resolution': null,
  'cash_payment':
      cash ??
      {
        'number': 'PAY-77',
        'amount': '1250.00',
        'currency': 'XAF',
        'status': 'pending',
        'payer_confirmed': true,
        'collector_confirmed': false,
        'outcome': 'disputed',
        'due_at': null,
      },
};

Future<FakeApi> _pump(
  WidgetTester tester,
  FakeReply Function(RequestOptions request) handler,
) async {
  final api = FakeApi((request) {
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
        authSessionProvider.overrideWith(_Agent.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const AgentComplaintScreen(complaintId: 9),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('a cash dispute shows the amount and who confirmed what', (
    tester,
  ) async {
    await _pump(tester, (_) => ok(_cashComplaint()));

    expect(find.text('Litige sur des espèces'), findsWidgets);
    expect(find.text('Arbitrage des espèces'), findsOneWidget);
    expect(find.textContaining('FCFA'), findsWidgets);
    expect(find.textContaining('client a confirmé'), findsOneWidget);
  });

  testWidgets('ruling against the collector asks a note then arbitrates', (
    tester,
  ) async {
    final api = await _pump(tester, (request) {
      if (request.method == 'POST') {
        return ok({'payment_number': 'PAY-77', 'order': 1});
      }
      return ok(_cashComplaint());
    });

    await tester.tap(find.text('Tort de l’encaisseur'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Preuve du client');
    await tester.tap(find.text('Arbitrer'));
    await tester.pumpAndSettle();

    final call = api.sent('POST', 'api/payments/PAY-77/cash/arbitrate/').single;
    expect(call.data, {
      'outcome': 'collector_at_fault',
      'note': 'Preuve du client',
    });
  });

  testWidgets('ruling against the customer sends the other outcome', (
    tester,
  ) async {
    final api = await _pump(tester, (request) {
      if (request.method == 'POST') {
        return ok({'payment_number': 'PAY-77', 'order': 1});
      }
      return ok(_cashComplaint());
    });

    await tester.tap(find.text('Tort du client'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Le client n’a rien payé');
    await tester.tap(find.text('Arbitrer'));
    await tester.pumpAndSettle();

    final call = api.sent('POST', 'api/payments/PAY-77/cash/arbitrate/').single;
    expect((call.data as Map)['outcome'], 'payer_at_fault');
  });

  testWidgets(
    'a closed payment or a complaint of one\'s own offers no ruling',
    (tester) async {
      await _pump(
        tester,
        (_) => ok(
          _cashComplaint(
            cash: {
              'number': 'PAY-77',
              'amount': '1250.00',
              'currency': 'XAF',
              'status': 'captured',
              'payer_confirmed': true,
              'collector_confirmed': true,
              'outcome': 'collector_at_fault',
              'due_at': null,
            },
          ),
        ),
      );

      expect(find.text('Tort de l’encaisseur'), findsNothing);
    },
  );

  testWidgets('an ordinary complaint has no cash card', (tester) async {
    await _pump(tester, (_) {
      final complaint = _cashComplaint();
      complaint['complaint_type'] = 'overcharge';
      complaint['cash_payment'] = null;
      return ok(complaint);
    });

    expect(find.text('Arbitrage des espèces'), findsNothing);
  });
}
