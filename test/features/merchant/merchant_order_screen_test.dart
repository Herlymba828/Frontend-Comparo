import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/formatters/price_formatter.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/merchant/merchant_order_screen.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _order({String mode = 'delivery'}) => {
  'id': 7,
  'order_number': 'ORD-2026-0007',
  'status': 'confirmed',
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
  String status = 'captured',
  String remaining = '',
}) => {
  'payment_number': 'PAY-7',
  'order': 7,
  'status': status,
  'amount': '3300.00',
  'currency': 'XAF',
  'amount_remaining': remaining,
  'method': 'mobile_money',
  'provider': 'airtel_money',
  'is_retryable': false,
};

Map<String, Object?> _pickup(String status) => {
  'id': 3,
  'order': 7,
  'status': status,
  'pickup_code': null,
  'location_name': 'Boutique Centre',
};

Map<String, Object?> _delivery(String status) => {
  'id': 5,
  'delivery_number': 'DLV-5',
  'order': 7,
  'status': status,
  'city': 'Libreville',
  'events': <Object?>[],
};

Map<String, Object?> _courier({
  int userId = 12,
  String name = 'Jean Moto',
  String phone = '+24106111111',
}) => {
  'id': 4,
  'user': userId,
  'display_name': name,
  'phone': phone,
  'vehicle': 'motorbike',
  'is_available': true,
  'max_active_deliveries': 3,
  'active_deliveries': 1,
  'zones': <Object?>[],
};

Map<String, Object?> _results(List<Object?> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

/// What the shop's order screen can read, and which calls the server refuses
/// ("METHOD path": message).
class _Backend {
  _Backend({
    Map<String, Object?>? order,
    this.payment,
    this.pickup,
    this.delivery,
    this.couriers = const [],
    this.fail = const {},
  }) : order = order ?? _order();

  final Map<String, Object?> order;
  final Map<String, Object?>? payment;
  final Map<String, Object?>? pickup;
  final Map<String, Object?>? delivery;
  final List<Map<String, Object?>> couriers;
  final Map<String, String> fail;

  FakeReply answer(RequestOptions request) {
    final key = '${request.method} ${request.path}';
    final refusal = fail[key];
    if (refusal != null) {
      return (
        status: 400,
        body: {
          'error': {'code': 'refused', 'detail': refusal},
        },
      );
    }
    return switch (key) {
      'GET api/orders/7/' => ok(order),
      'GET api/payments/' => ok(_results([?payment])),
      'GET api/delivery/pickups/' => ok(_results([?pickup])),
      'GET api/delivery/deliveries/' => ok(
        _results([
          if (delivery != null) {'id': 5},
        ]),
      ),
      'GET api/delivery/deliveries/5/' => ok(delivery ?? _delivery('pending')),
      'GET api/delivery/couriers/' => ok(_results(couriers)),
      // The server answers a refund with the updated payment.
      'POST api/payments/PAY-7/refund/' => ok(_payment(status: 'refunded')),
      _ => ok(<String, Object?>{}),
    };
  }
}

Future<FakeApi> _open(
  WidgetTester tester,
  _Backend backend, {
  AuthSessionController Function()? session,
}) async {
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeApi(backend.answer);
  await tester.pumpWidget(
    ProviderScope(
      // No automatic retry: a second attempt must come from the user.
      retry: (retryCount, error) => null,
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(session ?? MerchantSession.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MerchantOrderScreen(orderId: 7),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Finder get _dialog => find.byType(AlertDialog);

void main() {
  group('who can see the order', () {
    testWidgets('a customer without a shop is turned away', (tester) async {
      await _open(tester, _Backend(), session: SignedInSession.new);

      expect(
        find.text('Cet espace est réservé à un autre profil.'),
        findsOneWidget,
      );
    });

    testWidgets('a visitor is invited to sign in', (tester) async {
      await _open(tester, _Backend(), session: VisitorSession.new);

      expect(
        find.text('Connectez-vous pour accéder à cet espace.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the order that was received', (tester) async {
      await _open(tester, _Backend());

      expect(find.text('Commande reçue'), findsOneWidget);
      expect(find.text('ORD-2026-0007'), findsOneWidget);
    });

    testWidgets('an unreadable order shows the reason and can be retried', (
      tester,
    ) async {
      final api = await _open(
        tester,
        _Backend(fail: {'GET api/orders/7/': 'Commande introuvable.'}),
      );

      expect(find.text('Commande introuvable.'), findsOneWidget);
      final before = api.sent('GET', 'api/orders/7/').length;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(api.sent('GET', 'api/orders/7/').length, greaterThan(before));
    });

    testWidgets('a failing fulfilment list shows its reason', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'GET api/payments/': 'Paiements indisponibles.'}),
      );

      expect(find.text('Paiements indisponibles.'), findsOneWidget);
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final api = await _open(tester, _Backend());
      final before = api.sent('GET', 'api/orders/7/').length;

      await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(api.sent('GET', 'api/orders/7/').length, greaterThan(before));
    });
  });

  group('the payment', () {
    testWidgets('says when the customer has not paid yet', (tester) async {
      await _open(tester, _Backend());

      expect(find.text('Le client n’a pas encore payé.'), findsOneWidget);
      expect(find.text('Rembourser'), findsNothing);
    });

    testWidgets('can only be refunded once it was captured', (tester) async {
      await _open(tester, _Backend(payment: _payment(status: 'pending')));

      expect(find.text('Rembourser'), findsNothing);
    });

    testWidgets('a captured payment can be refunded with a reason', (
      tester,
    ) async {
      final api = await _open(tester, _Backend(payment: _payment()));

      await tester.tap(find.text('Rembourser'));
      await tester.pumpAndSettle();
      expect(find.text('Rembourser le client ?'), findsOneWidget);
      expect(
        find.textContaining(
          'Le montant restant (${formatPrice('3300.00', 'XAF')})',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Produit abîmé');
      await tester.tap(find.text('Rembourser').last);
      await tester.pumpAndSettle();

      final sent = api.sent('POST', 'api/payments/PAY-7/refund/').single;
      expect((sent.data as Map)['reason'], 'Produit abîmé');
      expect(sent.headers['Idempotency-Key'], isNotEmpty);
      expect(find.text('Remboursement enregistré.'), findsOneWidget);
    });

    testWidgets('without a reason, a default one is sent', (tester) async {
      final api = await _open(tester, _Backend(payment: _payment()));

      await tester.tap(find.text('Rembourser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rembourser').last);
      await tester.pumpAndSettle();

      final sent = api.sent('POST', 'api/payments/PAY-7/refund/').single;
      expect((sent.data as Map)['reason'], 'Remboursement marchand');
    });

    testWidgets('a partly refunded payment shows what is left to refund', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(
          payment: _payment(status: 'partial_refund', remaining: '1000.00'),
        ),
      );

      await tester.tap(find.text('Rembourser'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Le montant restant (${formatPrice('1000.00', 'XAF')})',
        ),
        findsOneWidget,
      );
    });

    testWidgets('going back sends nothing', (tester) async {
      final api = await _open(tester, _Backend(payment: _payment()));

      await tester.tap(find.text('Rembourser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/payments/PAY-7/refund/'), isEmpty);
    });

    testWidgets('a refused refund shows the reason', (tester) async {
      await _open(
        tester,
        _Backend(
          payment: _payment(),
          fail: {'POST api/payments/PAY-7/refund/': 'Déjà remboursé.'},
        ),
      );

      await tester.tap(find.text('Rembourser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rembourser').last);
      await tester.pumpAndSettle();

      expect(find.text('Déjà remboursé.'), findsOneWidget);
      expect(find.text('Remboursement enregistré.'), findsNothing);
    });
  });

  group('a pickup order', () {
    _Backend pickup(String status) => _Backend(
      order: _order(mode: 'pickup'),
      payment: _payment(),
      pickup: _pickup(status),
    );

    testWidgets('waits for the payment before preparing anything', (
      tester,
    ) async {
      await _open(tester, _Backend(order: _order(mode: 'pickup')));

      expect(
        find.text('Le retrait sera préparé une fois la commande payée.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the place, and no delivery section', (tester) async {
      await _open(tester, pickup('pending'));

      // The summary names the mode too, so the title appears twice.
      expect(find.text('Retrait en boutique'), findsWidgets);
      expect(find.text('Boutique Centre'), findsOneWidget);
      expect(find.text('Confier à un coursier'), findsNothing);
    });

    testWidgets('is marked ready, which warns the customer', (tester) async {
      final api = await _open(tester, pickup('pending'));

      await tester.tap(find.text('Commande prête'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/delivery/pickups/3/ready/'), hasLength(1));
      expect(
        find.text('Le client est prévenu que sa commande est prête.'),
        findsOneWidget,
      );
    });

    testWidgets('is handed over against the customer’s code', (tester) async {
      final api = await _open(tester, pickup('ready'));

      expect(find.text('Commande prête'), findsNothing);
      await tester.tap(find.text('Remise au client'));
      await tester.pumpAndSettle();
      expect(find.text('Code de retrait du client'), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' PKP-AB12CD ');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/delivery/pickups/3/confirm/').single.data, {
        'pickup_code': 'PKP-AB12CD',
      });
      expect(find.text('Retrait confirmé.'), findsOneWidget);
    });

    testWidgets('an empty code confirms nothing', (tester) async {
      final api = await _open(tester, pickup('ready'));

      await tester.tap(find.text('Remise au client'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/delivery/pickups/3/confirm/'), isEmpty);
    });

    testWidgets('a cancelled code dialog confirms nothing', (tester) async {
      final api = await _open(tester, pickup('ready'));

      await tester.tap(find.text('Remise au client'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/delivery/pickups/3/confirm/'), isEmpty);
      expect(_dialog, findsNothing);
    });

    testWidgets('a wrong code is refused with the reason', (tester) async {
      final backend = _Backend(
        order: _order(mode: 'pickup'),
        payment: _payment(),
        pickup: _pickup('ready'),
        fail: {'POST api/delivery/pickups/3/confirm/': 'Code incorrect.'},
      );
      await _open(tester, backend);

      await tester.tap(find.text('Remise au client'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'PKP-XXXXXX');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(find.text('Code incorrect.'), findsOneWidget);
      expect(find.text('Retrait confirmé.'), findsNothing);
    });

    testWidgets('a collected order has no action left', (tester) async {
      await _open(tester, pickup('collected'));

      expect(find.text('Commande prête'), findsNothing);
      expect(find.text('Remise au client'), findsNothing);
    });
  });

  group('a delivery order', () {
    _Backend delivery(String status, {List<Map<String, Object?>>? couriers}) =>
        _Backend(
          payment: _payment(),
          delivery: _delivery(status),
          couriers: couriers ?? [_courier()],
        );

    testWidgets('waits for the payment before organising anything', (
      tester,
    ) async {
      await _open(tester, _Backend());

      expect(
        find.text('La livraison sera organisée une fois la commande payée.'),
        findsOneWidget,
      );
    });

    testWidgets('is given to a courier chosen from the available ones', (
      tester,
    ) async {
      final api = await _open(
        tester,
        delivery(
          'pending',
          couriers: [
            _courier(),
            _courier(userId: 13, name: 'Awa Vélo', phone: ''),
          ],
        ),
      );

      await tester.tap(find.text('Confier à un coursier'));
      await tester.pumpAndSettle();
      expect(find.text('Choisir un coursier'), findsOneWidget);
      expect(find.text('Moto · 1 en cours · +24106111111'), findsOneWidget);
      expect(find.text('Moto · 1 en cours'), findsOneWidget);
      await tester.tap(find.text('Jean Moto'));
      await tester.pumpAndSettle();

      expect(
        api.sent('POST', 'api/delivery/deliveries/5/assign/').single.data,
        {'courier_id': 12},
      );
      expect(find.text('Coursier assigné.'), findsOneWidget);
    });

    testWidgets('says when no courier is available', (tester) async {
      await _open(tester, delivery('pending', couriers: const []));

      await tester.tap(find.text('Confier à un coursier'));
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun coursier disponible pour le moment.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
    });

    testWidgets('says why the couriers cannot be listed', (tester) async {
      await _open(
        tester,
        _Backend(
          payment: _payment(),
          delivery: _delivery('pending'),
          fail: {'GET api/delivery/couriers/': 'Liste indisponible.'},
        ),
      );

      await tester.tap(find.text('Confier à un coursier'));
      await tester.pumpAndSettle();

      expect(find.text('Liste indisponible.'), findsOneWidget);
    });

    testWidgets('a refused assignment shows the reason', (tester) async {
      await _open(
        tester,
        _Backend(
          payment: _payment(),
          delivery: _delivery('pending'),
          couriers: [_courier()],
          fail: {'POST api/delivery/deliveries/5/assign/': 'Coursier occupé.'},
        ),
      );

      await tester.tap(find.text('Confier à un coursier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jean Moto'));
      await tester.pumpAndSettle();

      expect(find.text('Coursier occupé.'), findsOneWidget);
      expect(find.text('Coursier assigné.'), findsNothing);
    });

    testWidgets('can no longer be reassigned once under way', (tester) async {
      await _open(tester, delivery('in_transit'));

      expect(find.text('Livraison DLV-5'), findsOneWidget);
      expect(find.text('Confier à un coursier'), findsNothing);
    });
  });
}
