import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/commerce/cash_repository.dart';
import 'package:frontend/features/commerce/cash_widgets.dart';
import 'package:frontend/features/commerce/commerce_models.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _payment({
  String status = 'pending',
  String method = 'cash',
  String? payerAt,
  String? collectorAt,
  String outcome = '',
}) => {
  'payment_number': 'PAY-1',
  'order': 7,
  'status': status,
  'amount': '1250.00',
  'currency': 'XAF',
  'method': method,
  'provider': 'manual',
  'payer_confirmed_at': payerAt,
  'collector_confirmed_at': collectorAt,
  'cash_outcome': outcome,
};

Map<String, Object?> _summary({
  bool payer = false,
  bool collector = false,
  String status = 'pending',
  String outcome = '',
}) => {
  'number': 'PAY-1',
  'amount': '1250.00',
  'currency': 'XAF',
  'status': status,
  'payer_confirmed': payer,
  'collector_confirmed': collector,
  'outcome': outcome,
  'due_at': null,
};

Future<FakeApi> _pump(
  WidgetTester tester,
  Widget child,
  FakeReply Function(RequestOptions) handler,
) async {
  final api = FakeApi(handler);
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [jsonApiProvider.overrideWithValue(api.jsonApi)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  return api;
}

void main() {
  group('models', () {
    test('a cash payment waits for the handover and cannot be cancelled', () {
      final cash = Payment.fromJson(_payment(payerAt: '2026-11-21T08:00:00Z'));
      expect(cash.isCash, isTrue);
      expect(cash.awaitsHandover, isTrue);
      expect(cash.isCancellable, isFalse);
      expect(cash.payerConfirmedAt, isNotNull);
      expect(cash.collectorConfirmedAt, isNull);
    });

    test('a mobile money payment keeps its cancellation', () {
      final mobile = Payment.fromJson(_payment(method: 'mobile_money'));
      expect(mobile.awaitsHandover, isFalse);
      expect(mobile.isCancellable, isTrue);
    });

    test('the cash to collect is read when the order is paid in cash', () {
      final delivery = Delivery.fromJson({
        'id': 5,
        'delivery_number': 'DLV-5',
        'order': 7,
        'status': 'in_transit',
        'cash_payment': _summary(payer: true),
      });
      expect(delivery.cashPayment?.payerConfirmed, isTrue);
      expect(delivery.cashPayment?.isWaiting, isTrue);

      final bare = Delivery.fromJson({
        'id': 6,
        'delivery_number': 'DLV-6',
        'order': 8,
        'cash_payment': null,
      });
      expect(bare.cashPayment, isNull);
    });
  });

  group('requests', () {
    test('each action reaches its own route', () async {
      final api = FakeApi((request) {
        if (request.method == 'GET') {
          return ok({'token': 'signed.token', 'expires_in': 600});
        }
        return ok(_payment());
      });
      final repo = CashRepository(api.jsonApi);

      await repo.payerConfirm('PAY-1');
      await repo.collectorConfirm('PAY-1');
      await repo.collectorDeny('PAY-1', 'Rien reçu');
      final qr = await repo.qr('PAY-1');
      await repo.scan('signed.token');

      expect(
        api.sent('POST', 'api/payments/PAY-1/cash/payer-confirm/'),
        hasLength(1),
      );
      expect(
        api.sent('POST', 'api/payments/PAY-1/cash/collector-confirm/'),
        hasLength(1),
      );
      final deny = api
          .sent('POST', 'api/payments/PAY-1/cash/collector-deny/')
          .single;
      expect((deny.data as Map)['reason'], 'Rien reçu');
      expect(qr.token, 'signed.token');
      expect(qr.expiresInSeconds, 600);
      final scan = api.sent('POST', 'api/payments/cash/scan/').single;
      expect((scan.data as Map)['token'], 'signed.token');
    });
  });

  group('the payer', () {
    testWidgets('confirms the handover or shows a QR code', (tester) async {
      var changed = 0;
      final api = await _pump(
        tester,
        CustomerCashActions(
          payment: Payment.fromJson(_payment()),
          onChanged: () => changed++,
        ),
        (request) => request.method == 'GET'
            ? ok({'token': 'signed.token', 'expires_in': 600})
            : ok(_payment(payerAt: '2026-11-21T08:00:00Z')),
      );

      expect(find.text('J’ai remis l’argent'), findsOneWidget);
      expect(find.text('Afficher mon code QR'), findsOneWidget);

      await tester.tap(find.text('J’ai remis l’argent'));
      await tester.pumpAndSettle();
      expect(
        api.sent('POST', 'api/payments/PAY-1/cash/payer-confirm/'),
        hasLength(1),
      );
      expect(changed, 1);
    });

    testWidgets('a confirmed payer waits for the collector', (tester) async {
      await _pump(
        tester,
        CustomerCashActions(
          payment: Payment.fromJson(_payment(payerAt: '2026-11-21T08:00:00Z')),
          onChanged: () {},
        ),
        (request) => ok(_payment()),
      );

      expect(find.text('J’ai remis l’argent'), findsNothing);
      expect(find.textContaining('en attente'), findsWidgets);
    });

    testWidgets('a captured payment shows nothing to do', (tester) async {
      await _pump(
        tester,
        CustomerCashActions(
          payment: Payment.fromJson(_payment(status: 'captured')),
          onChanged: () {},
        ),
        (request) => ok(_payment()),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('the collector', () {
    testWidgets('confirms the reception', (tester) async {
      var changed = 0;
      final api = await _pump(
        tester,
        CollectorCashCard(
          cash: CashSummary.fromJsonOrNull(_summary(payer: true))!,
          onChanged: () => changed++,
          scanner: (context) async => null,
        ),
        (request) => ok(_payment(collectorAt: '2026-11-21T08:00:00Z')),
      );

      expect(find.textContaining('FCFA'), findsWidgets);
      await tester.tap(find.text('J’ai reçu l’argent'));
      await tester.pumpAndSettle();

      expect(
        api.sent('POST', 'api/payments/PAY-1/cash/collector-confirm/'),
        hasLength(1),
      );
      expect(changed, 1);
    });

    testWidgets('denying asks why and opens the dispute', (tester) async {
      final api = await _pump(
        tester,
        CollectorCashCard(
          cash: CashSummary.fromJsonOrNull(_summary())!,
          onChanged: () {},
          scanner: (context) async => null,
        ),
        (request) => ok(_payment(outcome: 'disputed')),
      );

      await tester.tap(find.text('Je n’ai rien reçu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Le client n’a pas payé');
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();

      final deny = api
          .sent('POST', 'api/payments/PAY-1/cash/collector-deny/')
          .single;
      expect((deny.data as Map)['reason'], 'Le client n’a pas payé');
    });

    testWidgets('a scanned code settles the payment', (tester) async {
      var changed = 0;
      final api = await _pump(
        tester,
        CollectorCashCard(
          cash: CashSummary.fromJsonOrNull(_summary())!,
          onChanged: () => changed++,
          scanner: (context) async => 'signed.token',
        ),
        (request) => ok(_payment(status: 'captured')),
      );

      await tester.tap(find.text('Scanner le code du client'));
      await tester.pumpAndSettle();

      final scan = api.sent('POST', 'api/payments/cash/scan/').single;
      expect((scan.data as Map)['token'], 'signed.token');
      expect(changed, 1);
    });

    testWidgets('a cancelled scan sends nothing', (tester) async {
      final api = await _pump(
        tester,
        CollectorCashCard(
          cash: CashSummary.fromJsonOrNull(_summary())!,
          onChanged: () {},
          scanner: (context) async => null,
        ),
        (request) => ok(_payment()),
      );

      await tester.tap(find.text('Scanner le code du client'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/payments/cash/scan/'), isEmpty);
    });

    testWidgets('a closed payment hides the actions', (tester) async {
      await _pump(
        tester,
        CollectorCashCard(
          cash: CashSummary.fromJsonOrNull(
            _summary(status: 'captured', payer: true, collector: true),
          )!,
          onChanged: () {},
          scanner: (context) async => null,
        ),
        (request) => ok(_payment()),
      );

      expect(find.text('J’ai reçu l’argent'), findsNothing);
      expect(find.textContaining('confirmé'), findsWidgets);
    });
  });
}
