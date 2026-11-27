import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/commerce/order_detail_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _order({
  String status = 'pending',
  String mode = 'delivery',
}) => {
  'id': 7,
  'order_number': 'ORD-2026-0007',
  'status': status,
  'total': '3300.00',
  'currency': 'XAF',
  'delivery_mode': mode,
  'created_at': '2026-11-21T08:00:00Z',
  'items': [
    {
      'product_name': 'Riz complet',
      'quantity': '2.000',
      'unit_price': '1650.00',
      'line_total': '3300.00',
      'currency': 'XAF',
    },
  ],
};

Map<String, Object?> _payment({
  String status = 'pending',
  String method = 'cash',
  String? payerAt,
}) => {
  'payment_number': 'PAY-7',
  'order': 7,
  'status': status,
  'amount': '3300.00',
  'currency': 'XAF',
  'method': method,
  'provider': method == 'cash' ? 'manual' : 'airtel_money',
  'is_retryable': false,
  'payer_confirmed_at': payerAt,
};

Map<String, Object?> _delivery() => {
  'id': 5,
  'delivery_number': 'DLV-5',
  'order': 7,
  'status': 'in_transit',
  'city': 'Libreville',
  'events': <Object?>[],
};

/// Answers each route of the order screen from what the test gives it.
FakeReply Function(RequestOptions) _server({
  required Map<String, Object?> order,
  Map<String, Object?>? payment,
  Map<String, Object?>? delivery,
}) => (request) {
  final path = request.path;
  if (request.method == 'POST') {
    return path.contains('initiate')
        ? ok(_payment())
        : ok(
            path.contains('cancel') ? _order(status: 'cancelled') : _payment(),
          );
  }
  if (path == 'api/orders/7/') {
    return ok(order);
  }
  if (path == 'api/payments/') {
    return ok({
      'results': [?payment],
    });
  }
  if (path == 'api/delivery/deliveries/') {
    return ok({
      'results': [?delivery],
    });
  }
  if (path == 'api/delivery/deliveries/5/') {
    return ok(delivery ?? _delivery());
  }
  return ok({'results': <Object?>[]});
};

Future<FakeApi> _pump(
  WidgetTester tester,
  FakeReply Function(RequestOptions) handler,
) async {
  final api = FakeApi(handler);
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(SignedInSession.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const OrderDetailScreen(orderId: 7),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  group('an unpaid order', () {
    testWidgets('offers to pay or cancel', (tester) async {
      await _pump(tester, _server(order: _order()));

      expect(find.textContaining('Payer'), findsOneWidget);
      expect(find.text('Annuler la commande'), findsOneWidget);
      expect(find.textContaining('ORD-2026-0007'), findsWidgets);
    });

    testWidgets('can be paid in cash, to the courier as well as at a pickup', (
      tester,
    ) async {
      for (final mode in ['delivery', 'pickup']) {
        final api = await _pump(tester, _server(order: _order(mode: mode)));

        await tester.tap(find.textContaining('Payer'));
        await tester.pumpAndSettle();
        expect(find.text('Espèces à la remise'), findsOneWidget);
        await tester.tap(find.text('Espèces à la remise'));
        await tester.pump();
        await tester.tap(find.text('Payer').last);
        await tester.pumpAndSettle();

        final call = api.sent('POST', 'api/payments/initiate/').single;
        expect(call.headers['Idempotency-Key'], isNotEmpty, reason: mode);
        expect(call.data, containsPair('method', 'cash'));
        expect(call.data, containsPair('provider', 'manual'));
        expect(call.data, containsPair('order_id', 7));
      }
    });

    testWidgets('a mobile money payment keeps the number the customer typed', (
      tester,
    ) async {
      final api = await _pump(tester, _server(order: _order()));

      await tester.tap(find.textContaining('Payer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '+24106000000');
      await tester.tap(find.text('Payer').last);
      await tester.pumpAndSettle();

      final call = api.sent('POST', 'api/payments/initiate/').single;
      expect(call.data, containsPair('method', 'mobile_money'));
      expect(call.data, containsPair('provider', 'airtel_money'));
      expect(
        call.data,
        containsPair('payment_instrument_hint', '+24106000000'),
      );
    });

    testWidgets('cancelling asks first, then cancels', (tester) async {
      final api = await _pump(tester, _server(order: _order()));

      await tester.tap(find.text('Annuler la commande'));
      await tester.pumpAndSettle();
      expect(api.sent('POST', 'api/orders/7/cancel/'), isEmpty);
      await tester.tap(find.text('Annuler la commande').last);
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/orders/7/cancel/'), hasLength(1));
    });
  });

  group('a cash order being served', () {
    testWidgets('lets the payer confirm the handover', (tester) async {
      final api = await _pump(
        tester,
        _server(
          order: _order(status: 'confirmed'),
          payment: _payment(),
          delivery: _delivery(),
        ),
      );

      expect(find.text('J’ai remis l’argent'), findsOneWidget);
      expect(find.text('Annuler le paiement'), findsNothing);
      await tester.tap(find.text('J’ai remis l’argent'));
      await tester.pumpAndSettle();

      expect(
        api.sent('POST', 'api/payments/PAY-7/cash/payer-confirm/'),
        hasLength(1),
      );
    });

    testWidgets('shows the delivery under way', (tester) async {
      await _pump(
        tester,
        _server(
          order: _order(status: 'confirmed'),
          payment: _payment(payerAt: '2026-11-21T09:00:00Z'),
          delivery: _delivery(),
        ),
      );

      expect(find.text('J’ai remis l’argent'), findsNothing);
      expect(find.textContaining('DLV-5'), findsWidgets);
    });
  });

  testWidgets('a mobile money payment can be cancelled before capture', (
    tester,
  ) async {
    final api = await _pump(
      tester,
      _server(
        order: _order(),
        payment: _payment(method: 'mobile_money'),
      ),
    );

    expect(find.textContaining('Validez le paiement'), findsOneWidget);
    await tester.tap(find.text('Annuler le paiement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler le paiement').last);
    await tester.pumpAndSettle();

    expect(api.sent('POST', 'api/payments/PAY-7/cancel/'), hasLength(1));
  });
}
