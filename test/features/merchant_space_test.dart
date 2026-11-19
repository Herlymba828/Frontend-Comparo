import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/merchant/merchant_offers_screen.dart';
import 'package:frontend/features/merchant/merchant_shell.dart';
import 'package:frontend/features/merchant/merchant_stock_screen.dart';

import '../support/fake_api.dart';

Map<String, Object?> _shop({bool verified = true, bool active = true}) => {
  'id': 7,
  'name': 'Chez Mbolo',
  'description': '',
  'phone': '',
  'email': '',
  'status': verified ? 'active' : 'pending',
  'is_active': active,
  'is_verified': verified,
};

const _emptyPage = {'count': 0, 'next': null, 'results': <Object?>[]};

Future<FakeApi> _openMerchantTab(
  WidgetTester tester, {
  required AuthSessionController Function() session,
  required Object? shop,
  required String location,
  required Widget Function(int shopId) tab,
}) async {
  final api = FakeApi(
    (request) => request.path == 'api/merchants/me/'
        ? (shop == null
              ? (status: 404, body: {'detail': 'Aucune boutique.'})
              : ok(shop))
        : ok(_emptyPage),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(session),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MerchantShell(
          location: location,
          child: ShopPage(builder: (shop) => tab(shop.id)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('a customer without shop can open one from the merchant space', (
    tester,
  ) async {
    await _openMerchantTab(
      tester,
      session: SignedInSession.new,
      shop: null,
      location: '/merchant/orders',
      tab: (id) => const SizedBox.shrink(),
    );

    expect(
      find.text('Cet espace est réservé à un autre profil.'),
      findsNothing,
    );
    expect(find.text('Ouvrir ma boutique'), findsOneWidget);
  });

  testWidgets('a shop awaiting verification cannot start a new offer', (
    tester,
  ) async {
    await _openMerchantTab(
      tester,
      session: MerchantSession.new,
      shop: _shop(verified: false),
      location: '/merchant/offers',
      tab: (id) => MerchantOffersScreen(shopId: id),
    );

    expect(find.textContaining('en attente de vérification'), findsOneWidget);
    await tester.tap(find.text('Nouvelle offre'));
    await tester.pumpAndSettle();
    // No form: an explanation instead of a request the API would refuse.
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.textContaining('une fois votre boutique vérifiée'),
      findsWidgets,
    );
  });

  testWidgets('a shop awaiting verification cannot declare stock', (
    tester,
  ) async {
    await _openMerchantTab(
      tester,
      session: MerchantSession.new,
      shop: _shop(verified: false),
      location: '/merchant/stock',
      tab: (id) => MerchantStockScreen(shopId: id),
    );

    await tester.tap(find.text('Déclarer un stock'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a suspended shop is told why it cannot publish', (tester) async {
    await _openMerchantTab(
      tester,
      session: MerchantSession.new,
      shop: _shop(active: false),
      location: '/merchant/offers',
      tab: (id) => MerchantOffersScreen(shopId: id),
    );

    expect(find.textContaining('Boutique suspendue'), findsOneWidget);
    await tester.tap(find.text('Nouvelle offre'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a verified shop opens the new offer form', (tester) async {
    await _openMerchantTab(
      tester,
      session: MerchantSession.new,
      shop: _shop(),
      location: '/merchant/offers',
      tab: (id) => MerchantOffersScreen(shopId: id),
    );

    expect(find.textContaining('en attente de vérification'), findsNothing);
    await tester.tap(find.text('Nouvelle offre'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
