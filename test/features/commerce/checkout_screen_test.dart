import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/commerce/checkout_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _cart() => {
  'id': 4,
  'merchant': 2,
  'total': '3300.00',
  'item_count': 2,
  'items': [
    {
      'id': 9,
      'product': 3,
      'product_name': 'Riz complet',
      'quantity': '2.000',
      'unit_price_snapshot': '1650.00',
      'current_price': '1650.00',
      'line_total': '3300.00',
      'currency_snapshot': 'XAF',
      'price_changed': false,
    },
  ],
};

Map<String, Object?> _order() => {
  'id': 11,
  'order_number': 'ORD-2026-0011',
  'status': 'pending',
  'total': '3300.00',
  'currency': 'XAF',
  'delivery_mode': 'delivery',
  'created_at': '2026-11-21T08:00:00Z',
  'items': <Object?>[],
};

final _address = {
  'id': 3,
  'label': 'Maison',
  'recipient_name': 'Awa Ndong',
  'phone': '+24106000000',
  'street': 'Rue des Palmiers',
  'city': 'Libreville',
  'additional_info': '',
  'is_default': true,
};

final _store = {
  'id': 8,
  'name': 'Boutique du port',
  'street': 'Quai 2',
  'city': 'Libreville',
  'phone': '',
  'is_main': true,
};

Future<FakeApi> _pump(
  WidgetTester tester,
  FakeReply Function(RequestOptions) handler,
) async {
  final api = FakeApi(handler);
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/checkout',
    routes: [
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            Scaffold(body: Text('Commande ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(SignedInSession.new),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

FakeReply Function(RequestOptions) _server({
  FakeReply Function(RequestOptions)? checkout,
  bool withAddress = true,
}) => (request) {
  if (request.method == 'POST' && request.path == 'api/orders/checkout/') {
    return checkout?.call(request) ?? ok(_order());
  }
  return switch (request.path) {
    'api/cart/' => ok(_cart()),
    'api/delivery/addresses/' => ok({
      'results': [if (withAddress) _address],
    }),
    'api/merchants/2/locations/' => ok({
      'results': [_store],
    }),
    _ => ok({'results': <Object?>[]}),
  };
};

void main() {
  testWidgets('a delivery order carries the chosen address and a key', (
    tester,
  ) async {
    final api = await _pump(tester, _server());

    await tester.tap(find.byType(RadioListTile<int>).first);
    await tester.pump();
    await tester.tap(find.text('Valider la commande'));
    await tester.pumpAndSettle();

    final call = api.sent('POST', 'api/orders/checkout/').single;
    expect(call.headers['Idempotency-Key'], isNotEmpty);
    expect(call.data, containsPair('delivery_mode', 'delivery'));
    expect(call.data, containsPair('delivery_address_id', 3));
    expect(find.text('Commande 11'), findsOneWidget);
  });

  testWidgets('nothing is sent without an address', (tester) async {
    final api = await _pump(tester, _server(withAddress: false));

    await tester.tap(find.text('Valider la commande'));
    await tester.pumpAndSettle();

    expect(find.textContaining('adresse de livraison'), findsOneWidget);
    expect(api.sent('POST', 'api/orders/checkout/'), isEmpty);
  });

  testWidgets('a pickup order asks for a pickup point first', (tester) async {
    final api = await _pump(tester, _server());

    await tester.tap(find.text('Retrait'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider la commande'));
    await tester.pumpAndSettle();
    expect(find.textContaining('point de retrait'), findsWidgets);
    expect(api.sent('POST', 'api/orders/checkout/'), isEmpty);

    await tester.tap(find.byType(RadioListTile<int>).first);
    await tester.pump();
    await tester.tap(find.text('Valider la commande'));
    await tester.pumpAndSettle();

    final call = api.sent('POST', 'api/orders/checkout/').single;
    expect(call.data, containsPair('delivery_mode', 'pickup'));
    expect(call.data, containsPair('pickup_location_id', 8));
  });

  testWidgets('moved prices are shown and re-sent only once accepted', (
    tester,
  ) async {
    var first = true;
    final api = await _pump(
      tester,
      _server(
        checkout: (request) {
          if (first) {
            first = false;
            return (
              status: 409,
              body: {
                'error': {
                  'code': 'price_changed',
                  'detail': 'Des prix ont changé.',
                  'fields': {
                    'changes': [
                      {
                        'product_name': 'Riz complet',
                        'old_price': '1650.00',
                        'new_price': '1800.00',
                      },
                    ],
                  },
                },
              },
            );
          }
          return ok(_order());
        },
      ),
    );

    await tester.tap(find.byType(RadioListTile<int>).first);
    await tester.pump();
    await tester.tap(find.text('Valider la commande'));
    await tester.pumpAndSettle();
    expect(find.text('Des prix ont changé'), findsOneWidget);

    await tester.tap(find.text('Commander à ces prix'));
    await tester.pumpAndSettle();

    final sent = api.sent('POST', 'api/orders/checkout/');
    expect(sent, hasLength(2));
    expect((sent.first.data as Map)['accept_price_changes'], isFalse);
    expect((sent.last.data as Map)['accept_price_changes'], isTrue);
    expect(find.text('Commande 11'), findsOneWidget);
  });

  testWidgets('refusing the new prices sends nothing more', (tester) async {
    final api = await _pump(
      tester,
      _server(
        checkout: (_) => (
          status: 409,
          body: {
            'error': {
              'code': 'price_changed',
              'detail': 'Des prix ont changé.',
              'fields': {'changes': <Object?>[]},
            },
          },
        ),
      ),
    );

    await tester.tap(find.byType(RadioListTile<int>).first);
    await tester.pump();
    await tester.tap(find.text('Valider la commande'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoir le panier'));
    await tester.pumpAndSettle();

    expect(api.sent('POST', 'api/orders/checkout/'), hasLength(1));
  });
}
