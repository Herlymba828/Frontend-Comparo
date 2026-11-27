import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/courier/courier_deliveries_screen.dart';
import 'package:frontend/features/courier/courier_delivery_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/models/auth_user.dart';

import '../../support/fake_api.dart';

class _Courier extends AuthSessionController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    id: 20,
    email: 'livreur@demo.ga',
    displayName: 'Livreur',
    emailVerified: true,
    roles: ['consumer', 'courier'],
  );
}

Map<String, Object?> _delivery({
  int id = 5,
  String status = 'assigned',
  int? courier = 20,
  bool proof = false,
  Map<String, Object?>? cash,
}) => {
  'id': id,
  'delivery_number': 'DLV-$id',
  'order': 7,
  'status': status,
  'courier': courier,
  'city': 'Libreville',
  'street': 'Rue des Palmiers',
  'recipient_name': 'Awa Ndong',
  'recipient_phone': '+24106000000',
  'proof_photo_url': proof ? 'https://cdn.example.com/p.jpg' : '',
  'events': <Object?>[],
  'cash_payment': cash,
};

Map<String, Object?> _cash({bool payer = false}) => {
  'number': 'PAY-7',
  'amount': '3300.00',
  'currency': 'XAF',
  'status': 'pending',
  'payer_confirmed': payer,
  'collector_confirmed': false,
  'outcome': '',
  'due_at': null,
};

Future<FakeApi> _pump(
  WidgetTester tester,
  Widget screen,
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
        authSessionProvider.overrideWith(_Courier.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

FakeReply Function(RequestOptions) _server(Map<String, Object?> delivery) =>
    (request) => request.method == 'POST' ? ok(delivery) : ok(delivery);

void main() {
  group('the delivery list', () {
    testWidgets('shows only the runs the courier carries', (tester) async {
      await _pump(
        tester,
        const CourierDeliveriesScreen(available: false),
        (_) => ok({
          'results': [_delivery(id: 5), _delivery(id: 6, courier: 99)],
        }),
      );

      expect(find.text('DLV-5'), findsOneWidget);
      expect(find.text('DLV-6'), findsNothing);
    });

    testWidgets('open runs are all shown and the list can be empty', (
      tester,
    ) async {
      await _pump(
        tester,
        const CourierDeliveriesScreen(available: true),
        (_) => ok({'results': <Object?>[]}),
      );

      expect(
        find.text('Aucune livraison ouverte dans vos zones.'),
        findsOneWidget,
      );
    });
  });

  group('a delivery', () {
    testWidgets('an open run is claimed', (tester) async {
      final api = await _pump(
        tester,
        const CourierDeliveryScreen(deliveryId: 5),
        _server(_delivery(status: 'pending', courier: null)),
      );

      await tester.tap(find.text('Prendre cette course'));
      await tester.pumpAndSettle();

      expect(
        api.sent('POST', 'api/delivery/deliveries/5/claim/'),
        hasLength(1),
      );
    });

    testWidgets('an assigned run starts, or fails with a reason', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        const CourierDeliveryScreen(deliveryId: 5),
        _server(_delivery()),
      );

      await tester.tap(find.text('Colis récupéré, en route'));
      await tester.pumpAndSettle();
      expect(
        (api.sent('POST', 'api/delivery/deliveries/5/status/').single.data
            as Map)['status'],
        'in_transit',
      );
    });

    testWidgets('delivered is offered only once a proof is recorded', (
      tester,
    ) async {
      await _pump(
        tester,
        const CourierDeliveryScreen(deliveryId: 5),
        _server(_delivery(status: 'in_transit')),
      );
      expect(find.text('Marquer comme livrée'), findsNothing);
      expect(find.text('Enregistrer la preuve'), findsOneWidget);

      await _pump(
        tester,
        const CourierDeliveryScreen(deliveryId: 5),
        _server(_delivery(status: 'in_transit', proof: true)),
      );
      expect(find.text('Marquer comme livrée'), findsOneWidget);
    });

    testWidgets('a failed run can be returned to the merchant', (tester) async {
      final api = await _pump(
        tester,
        const CourierDeliveryScreen(deliveryId: 5),
        _server(_delivery(status: 'failed')),
      );

      await tester.tap(find.text('Colis retourné au marchand'));
      await tester.pumpAndSettle();

      expect(
        (api.sent('POST', 'api/delivery/deliveries/5/status/').single.data
            as Map)['status'],
        'returned',
      );
    });

    testWidgets('the cash to collect shows on the courier\'s own run', (
      tester,
    ) async {
      await _pump(
        tester,
        const CourierDeliveryScreen(deliveryId: 5),
        _server(_delivery(status: 'in_transit', cash: _cash(payer: true))),
      );

      expect(find.text('Espèces à encaisser'), findsOneWidget);
      expect(find.text('J’ai reçu l’argent'), findsOneWidget);
      expect(find.text('Scanner le code du client'), findsOneWidget);
    });

    testWidgets('another courier\'s run shows no cash to collect', (
      tester,
    ) async {
      await _pump(
        tester,
        const CourierDeliveryScreen(deliveryId: 5),
        _server(_delivery(status: 'in_transit', courier: 99, cash: _cash())),
      );

      expect(find.text('Espèces à encaisser'), findsNothing);
    });
  });
}
