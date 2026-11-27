import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/merchant/merchant_repository.dart';
import 'package:frontend/features/merchant/merchant_shop_screen.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_api.dart';

Shop _shop({
  bool verified = true,
  String description = 'Épicerie du quartier',
  String phone = '+24106000000',
  String logoUrl = '',
}) => Shop(
  id: 7,
  name: 'Chez Mbolo',
  description: description,
  phone: phone,
  email: '',
  status: verified ? 'active' : 'pending',
  isVerified: verified,
  logoUrl: logoUrl,
);

Map<String, Object?> _results(List<Object?> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

Map<String, Object?> _location(
  int id,
  String name, {
  bool main = false,
  bool active = true,
}) => {
  'id': id,
  'name': name,
  'street': 'Rue $id',
  'city': 'Libreville',
  'phone': '',
  'is_main': main,
  'is_active': active,
};

Map<String, Object?> _roles({String? status, String message = ''}) => {
  'grants': <Object?>[],
  'applications': [
    if (status != null)
      {
        'id': 9,
        'role': 'merchant',
        'status': status,
        'reviewer_message': message,
      },
  ],
};

class _Backend {
  _Backend({
    this.locations = const [],
    Map<String, Object?>? roles,
    this.fail = const {},
  }) : roles = roles ?? _roles();

  final List<Map<String, Object?>> locations;
  final Map<String, Object?> roles;
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
      'GET api/merchants/7/locations/' => ok(_results(locations)),
      'GET api/roles/mine/' => ok(roles),
      _ => ok(<String, Object?>{}),
    };
  }
}

Future<FakeApi> _open(
  WidgetTester tester,
  _Backend backend, {
  Shop? shop,
}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeApi(backend.answer);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: MerchantShopScreen(shop: shop ?? _shop())),
      ),
      GoRoute(
        path: '/account/roles/applications/:id',
        builder: (context, state) =>
            Scaffold(body: Text('Dossier ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      // No automatic retry: a second attempt must come from the user.
      retry: (retryCount, error) => null,
      overrides: [jsonApiProvider.overrideWithValue(api.jsonApi)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Finder get _dialog => find.byType(AlertDialog);

Future<void> _openMenu(WidgetTester tester, int row) async {
  await tester.tap(find.byType(PopupMenuButton<String>).at(row));
  await tester.pumpAndSettle();
}

void main() {
  group('the shop card', () {
    testWidgets('shows what customers see of the shop', (tester) async {
      await _open(tester, _Backend());

      expect(find.text('Chez Mbolo'), findsOneWidget);
      expect(find.text('Épicerie du quartier'), findsOneWidget);
      expect(find.text('+24106000000'), findsOneWidget);
    });

    testWidgets('shows a dash for what is not filled in', (tester) async {
      await _open(
        tester,
        _Backend(),
        shop: _shop(description: '', phone: ''),
      );

      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('is edited and saved', (tester) async {
      final api = await _open(tester, _Backend());

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      expect(find.text('Ma boutique'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('Nom')).controller!.text,
        'Chez Mbolo',
      );
      await tester.enterText(_field('Nom'), '  Chez Mbolo & fils ');
      await tester.enterText(_field('Téléphone'), '+24106999999');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(api.sent('PATCH', 'api/merchants/7/').single.data, {
        'name': 'Chez Mbolo & fils',
        'description': 'Épicerie du quartier',
        'phone': '+24106999999',
      });
    });

    testWidgets('leaves the shop alone when the edit is cancelled', (
      tester,
    ) async {
      final api = await _open(tester, _Backend());

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.sent('PATCH', 'api/merchants/7/'), isEmpty);
      expect(_dialog, findsNothing);
    });

    testWidgets('shows why a change was refused', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'PATCH api/merchants/7/': 'Nom déjà pris.'}),
      );

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Nom déjà pris.'), findsOneWidget);
    });
  });

  group('the logo', () {
    testWidgets('can be added when there is none', (tester) async {
      await _open(tester, _Backend());

      expect(find.text('Ajouter un logo'), findsOneWidget);
      expect(find.text('Retirer'), findsNothing);
      expect(
        find.text('Image JPEG ou PNG, carrée de préférence, 1 Mo au plus.'),
        findsOneWidget,
      );
    });

    testWidgets('can be changed or removed when there is one', (tester) async {
      final api = await _open(
        tester,
        _Backend(),
        shop: _shop(logoUrl: 'https://img.example.test/logo.png'),
      );

      expect(find.text('Changer'), findsOneWidget);
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/merchants/me/logo/'), hasLength(1));
    });

    testWidgets('shows why the logo could not be removed', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'DELETE api/merchants/me/logo/': 'Logo verrouillé.'}),
        shop: _shop(logoUrl: 'https://img.example.test/logo.png'),
      );

      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      expect(find.text('Logo verrouillé.'), findsOneWidget);
    });
  });

  group('the merchant application', () {
    testWidgets('a verified shop without a file is simply verified', (
      tester,
    ) async {
      await _open(tester, _Backend());

      expect(find.text('Boutique vérifiée.'), findsOneWidget);
    });

    testWidgets('an unverified shop without a file points to the help', (
      tester,
    ) async {
      await _open(tester, _Backend(), shop: _shop(verified: false));

      expect(
        find.text('Aucune candidature pour cette boutique. Contactez l’aide.'),
        findsOneWidget,
      );
    });

    testWidgets('a draft can be completed, with what the team asked', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(
          roles: _roles(status: 'draft', message: 'Ajoutez la photo.'),
        ),
        shop: _shop(verified: false),
      );

      expect(find.text('État du dossier'), findsOneWidget);
      // The status stamp prints its label in capitals.
      expect(find.text('BROUILLON'), findsOneWidget);
      expect(find.text('Ajoutez la photo.'), findsOneWidget);
      expect(find.textContaining('Pièce d’identité'), findsOneWidget);

      await tester.tap(find.text('Compléter mon dossier'));
      await tester.pumpAndSettle();

      expect(find.text('Dossier 9'), findsOneWidget);
    });

    testWidgets('a file under review can only be followed', (tester) async {
      await _open(
        tester,
        _Backend(roles: _roles(status: 'submitted')),
        shop: _shop(verified: false),
      );

      expect(
        find.textContaining('L’équipe examine votre dossier'),
        findsOneWidget,
      );
      expect(find.text('Compléter mon dossier'), findsNothing);
      await tester.tap(find.text('Suivre mon dossier'));
      await tester.pumpAndSettle();

      expect(find.text('Dossier 9'), findsOneWidget);
    });

    testWidgets('a verified shop keeps its documents', (tester) async {
      await _open(tester, _Backend(roles: _roles(status: 'approved')));

      expect(
        find.text('Boutique vérifiée : vos justificatifs sont conservés.'),
        findsOneWidget,
      );
    });

    testWidgets('a failure shows why and can be retried', (tester) async {
      final api = await _open(
        tester,
        _Backend(fail: {'GET api/roles/mine/': 'Dossier indisponible.'}),
      );

      expect(find.text('Dossier indisponible.'), findsOneWidget);
      final before = api.sent('GET', 'api/roles/mine/').length;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(api.sent('GET', 'api/roles/mine/').length, greaterThan(before));
    });
  });

  group('the pickup points', () {
    testWidgets('invite the merchant to add the first one', (tester) async {
      await _open(tester, _Backend());

      expect(
        find.text(
          'Ajoutez un point de retrait pour proposer le click & collect.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('are listed, the main one starred, a closed one marked', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(
          locations: [
            _location(1, 'Centre', main: true),
            _location(2, 'Marché', active: false),
          ],
        ),
      );

      expect(find.text('Centre'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Rue 1 · Libreville'), findsOneWidget);
      expect(find.text('Rue 2 · Libreville · fermé'), findsOneWidget);
    });

    testWidgets('say why the list could not be loaded', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'GET api/merchants/7/locations/': 'Points absents.'}),
      );

      expect(find.text('Points absents.'), findsOneWidget);
    });

    testWidgets('a secondary open one can become the main one', (tester) async {
      final api = await _open(
        tester,
        _Backend(
          locations: [
            _location(1, 'Centre', main: true),
            _location(2, 'Marché'),
          ],
        ),
      );

      await _openMenu(tester, 1);
      expect(find.text('Point principal'), findsOneWidget);
      await tester.tap(find.text('Point principal'));
      await tester.pumpAndSettle();

      expect(
        api.sent('POST', 'api/merchants/7/locations/2/set_main/'),
        hasLength(1),
      );
    });

    testWidgets('the main one can only be closed', (tester) async {
      final api = await _open(
        tester,
        _Backend(locations: [_location(1, 'Centre', main: true)]),
      );

      await _openMenu(tester, 0);
      expect(find.text('Point principal'), findsNothing);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      expect(api.sent('PATCH', 'api/merchants/7/locations/1/').single.data, {
        'is_active': false,
      });
    });

    testWidgets('a closed one can be reopened but not made the main one', (
      tester,
    ) async {
      final api = await _open(
        tester,
        _Backend(locations: [_location(2, 'Marché', active: false)]),
      );

      await _openMenu(tester, 0);
      expect(find.text('Point principal'), findsNothing);
      await tester.tap(find.text('Rouvrir'));
      await tester.pumpAndSettle();

      expect(api.sent('PATCH', 'api/merchants/7/locations/2/').single.data, {
        'is_active': true,
      });
    });

    testWidgets('a refused change shows the reason', (tester) async {
      await _open(
        tester,
        _Backend(
          locations: [_location(1, 'Centre', main: true)],
          fail: {'PATCH api/merchants/7/locations/1/': 'Dernier point ouvert.'},
        ),
      );

      await _openMenu(tester, 0);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      expect(find.text('Dernier point ouvert.'), findsOneWidget);
    });
  });

  group('a new pickup point', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Ajouter un point de retrait'));
      await tester.pumpAndSettle();
    }

    testWidgets('is added with its address, in Libreville by default', (
      tester,
    ) async {
      final api = await _open(tester, _Backend());
      await openDialog(tester);

      expect(find.text('Nouveau point de retrait'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('Ville')).controller!.text,
        'Libreville',
      );
      await tester.enterText(_field('Nom'), '  Centre ');
      await tester.enterText(_field('Rue / quartier'), 'Avenue Léon Mba');
      await tester.enterText(_field('Téléphone'), '+24106111111');
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/merchants/7/locations/').single.data, {
        'name': 'Centre',
        'street': 'Avenue Léon Mba',
        'city': 'Libreville',
        'country': 'GA',
        'phone': '+24106111111',
        'is_main': false,
      });
    });

    testWidgets('needs a name and a street', (tester) async {
      final api = await _open(tester, _Backend());
      await openDialog(tester);

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);

      await tester.enterText(_field('Nom'), 'Centre');
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(api.sent('POST', 'api/merchants/7/locations/'), isEmpty);
    });

    testWidgets('can be cancelled', (tester) async {
      final api = await _open(tester, _Backend());
      await openDialog(tester);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(api.sent('POST', 'api/merchants/7/locations/'), isEmpty);
    });

    testWidgets('a refusal shows the reason', (tester) async {
      await _open(
        tester,
        _Backend(
          fail: {'POST api/merchants/7/locations/': 'Adresse invalide.'},
        ),
      );
      await openDialog(tester);
      await tester.enterText(_field('Nom'), 'Centre');
      await tester.enterText(_field('Rue / quartier'), 'Rue 1');

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(find.text('Adresse invalide.'), findsOneWidget);
    });
  });
}
