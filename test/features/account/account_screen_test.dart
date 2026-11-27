import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/account/account_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/models/auth_user.dart';

import '../../support/fake_api.dart';

class _As extends AuthSessionController {
  _As(this.roles);

  final List<String> roles;

  @override
  Future<AuthUser?> build() async => AuthUser(
    id: 1,
    email: 'moi@demo.ga',
    displayName: 'Moi',
    emailVerified: true,
    roles: roles,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  List<String> roles = const ['consumer'],
}) async {
  final api = FakeApi((_) => ok({'results': <Object?>[]}));
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AccountScreen()),
      for (final path in [
        '/cart',
        '/orders',
        '/alerts',
        '/support',
        '/account/privacy',
        '/account/roles',
        '/account/channels',
        '/account/profile',
        '/courier/deliveries',
        '/merchant/orders',
      ])
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(body: Text('vers $path')),
        ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(() => _As(roles)),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a customer sees the shopping entries and the way to a shop', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Mon panier'), findsOneWidget);
    expect(find.text('Mes commandes'), findsOneWidget);
    expect(find.text('Ouvrir ma boutique'), findsOneWidget);
    expect(find.text('Mes rôles et candidatures'), findsOneWidget);
    expect(find.text('Confidentialité'), findsOneWidget);
  });

  testWidgets('a merchant already has a shop to open instead', (tester) async {
    await _pump(tester, roles: const ['consumer', 'merchant']);

    expect(find.text('Ouvrir ma boutique'), findsNothing);
    expect(find.text('Mes espaces'), findsOneWidget);
  });

  testWidgets('a courier gets the way to the courier space', (tester) async {
    await _pump(tester, roles: const ['consumer', 'courier']);

    await tester.scrollUntilVisible(
      find.text('Espace coursier'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Espace coursier'));
    await tester.pumpAndSettle();

    expect(find.text('vers /courier/deliveries'), findsOneWidget);
  });

  testWidgets('an entry opens its screen', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Mes commandes'));
    await tester.pumpAndSettle();

    expect(find.text('vers /orders'), findsOneWidget);
  });

  testWidgets('the privacy entry is reachable', (tester) async {
    await _pump(tester);

    await tester.scrollUntilVisible(
      find.text('Confidentialité'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Confidentialité'));
    await tester.pumpAndSettle();

    expect(find.text('vers /account/privacy'), findsOneWidget);
  });

  testWidgets('signing out asks first and keeps the session when declined', (
    tester,
  ) async {
    await _pump(tester);

    await tester.scrollUntilVisible(
      find.text('Se déconnecter'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(find.text('Se déconnecter ?'), findsOneWidget);
    expect(find.textContaining('hors ligne seront effacées'), findsOneWidget);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('Mon compte'), findsOneWidget);
    expect(find.text('Se déconnecter ?'), findsNothing);
  });
}
