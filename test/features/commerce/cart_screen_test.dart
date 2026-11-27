import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/commerce/cart_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _cart({int quantity = 2}) => {
  'id': 4,
  'merchant': 2,
  'total': '${1650 * quantity}.00',
  'item_count': quantity,
  'items': [
    {
      'id': 9,
      'product': 3,
      'product_name': 'Riz complet',
      'quantity': '$quantity.000',
      'unit_price_snapshot': '1650.00',
      'current_price': '1650.00',
      'line_total': '${1650 * quantity}.00',
      'currency_snapshot': 'XAF',
      'price_changed': false,
    },
  ],
};

Map<String, Object?> get _emptyCart => {
  'id': 4,
  'merchant': null,
  'total': '0',
  'item_count': 0,
  'items': <Object?>[],
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
    routes: [
      GoRoute(path: '/', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) =>
            const Scaffold(body: Text('Écran de commande')),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const Scaffold(body: Text('Recherche')),
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

void main() {
  testWidgets('an empty cart sends the customer to the search', (tester) async {
    await _pump(tester, (_) => ok(_emptyCart));

    expect(find.text('Votre panier est vide.'), findsOneWidget);
    await tester.tap(find.text('Chercher un produit'));
    await tester.pumpAndSettle();
    expect(find.text('Recherche'), findsOneWidget);
  });

  testWidgets('the quantity of a line goes up, down, and the line goes', (
    tester,
  ) async {
    final api = await _pump(tester, (request) {
      return ok(request.method == 'GET' ? _cart() : _cart(quantity: 3));
    });

    expect(find.text('Riz complet'), findsOneWidget);
    await tester.tap(find.byTooltip('Ajouter un'));
    await tester.pumpAndSettle();
    final patch = api.sent('PATCH', 'api/cart/items/9/').single;
    expect((patch.data as Map)['quantity'], '3');

    await tester.tap(find.byTooltip('Retirer du panier'));
    await tester.pumpAndSettle();
    expect(api.sent('DELETE', 'api/cart/items/9/'), hasLength(1));
  });

  testWidgets('a cart is emptied only after the customer agrees', (
    tester,
  ) async {
    final api = await _pump(tester, (_) => ok(_cart()));

    await tester.tap(find.text('Vider le panier'));
    await tester.pumpAndSettle();
    expect(api.sent('DELETE', 'api/cart/'), isEmpty);
    await tester.tap(find.text('Vider'));
    await tester.pumpAndSettle();

    expect(api.sent('DELETE', 'api/cart/'), hasLength(1));
  });

  testWidgets('a valid cart goes on to the order', (tester) async {
    await _pump(tester, (request) {
      return request.path == 'api/cart/validate/'
          ? ok({'valid': true, 'errors': <Object?>[], 'warnings': <Object?>[]})
          : ok(_cart());
    });

    await tester.tap(find.text('Passer la commande'));
    await tester.pumpAndSettle();

    expect(find.text('Écran de commande'), findsOneWidget);
  });

  testWidgets('an invalid cart says what to fix and stays', (tester) async {
    await _pump(tester, (request) {
      return request.path == 'api/cart/validate/'
          ? ok({
              'valid': false,
              'errors': ['Riz complet n’est plus disponible.'],
              'warnings': <Object?>[],
            })
          : ok(_cart());
    });

    await tester.tap(find.text('Passer la commande'));
    // The check's spinner turns while the dialog is open: no settling.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Panier à corriger'), findsOneWidget);
    expect(find.textContaining('plus disponible'), findsOneWidget);
    await tester.tap(find.text('Compris'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Écran de commande'), findsNothing);
  });
}
