import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/account/account_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/models/auth_user.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _page(List<Map<String, Object?>> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

Map<String, Object?> _device(String id, String name, {String place = ''}) => {
  'id': id,
  'device_name': name,
  'location': place,
  'last_activity_at': '2026-11-20T10:30:00Z',
};

Map<String, Object?> _notification(
  int id,
  String title, {
  bool unread = true,
}) => {
  'id': id,
  'title': title,
  'body': 'Détail de $title',
  'is_unread': unread,
  'created_at': '2026-11-20T09:00:00Z',
  'action_url': '',
};

/// A signed-in session that records how it ended, without touching the
/// device storage.
class _Session extends AuthSessionController {
  static AuthUser user = const AuthUser(
    id: 1,
    email: 'moi@demo.ga',
    displayName: 'Moi',
    emailVerified: true,
    phone: '+24106000000',
    city: 'Libreville',
  );
  static int revoked = 0;
  static int loggedOut = 0;
  static bool logoutFails = false;

  static void reset([AuthUser? next]) {
    user =
        next ??
        const AuthUser(
          id: 1,
          email: 'moi@demo.ga',
          displayName: 'Moi',
          emailVerified: true,
          phone: '+24106000000',
          city: 'Libreville',
        );
    revoked = 0;
    loggedOut = 0;
    logoutFails = false;
  }

  @override
  Future<AuthUser?> build() async => user;

  @override
  Future<void> endRevokedSession() async {
    revoked++;
    state = const AsyncData(null);
  }

  @override
  Future<void> logout() async {
    loggedOut++;
    state = const AsyncData(null);
    if (logoutFails) {
      throw Exception('hors ligne');
    }
  }
}

/// What the API holds and which calls it refuses ("METHOD path": message).
class _Backend {
  _Backend({
    this.sessions = const [],
    this.notifications = const [],
    this.fail = const {},
    this.refuseAfterFirst = const {},
  });

  final List<Map<String, Object?>> sessions;
  final List<Map<String, Object?>> notifications;
  final Map<String, String> fail;

  /// Calls that succeed once, then are refused with the given message.
  final Map<String, String> refuseAfterFirst;
  final _seen = <String, int>{};

  FakeReply answer(RequestOptions request) {
    final key = '${request.method} ${request.path}';
    final times = _seen[key] = (_seen[key] ?? 0) + 1;
    final refusal = fail[key] ?? (times > 1 ? refuseAfterFirst[key] : null);
    if (refusal != null) {
      return (
        status: 400,
        body: {
          'error': {'code': 'refused', 'detail': refusal},
        },
      );
    }
    return switch (key) {
      'GET api/auth/sessions/' => ok(_page(sessions)),
      'GET api/notifications/' => ok(_page(notifications)),
      _ => ok(<String, Object?>{}),
    };
  }
}

Future<FakeApi> _open(
  WidgetTester tester,
  _Backend backend, {
  required String location,
  bool visitor = false,
}) async {
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeApi(backend.answer);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Accueil')),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) =>
            const Scaffold(body: Text('Page de connexion')),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/account/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      for (final path in [
        '/cart',
        '/orders',
        '/alerts',
        '/support',
        '/assistant',
        '/contributions',
        '/account/favorites',
        '/account/budgets',
        '/account/roles',
        '/account/channels',
        '/account/privacy',
        '/merchant/orders',
      ])
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(body: Text('vers $path')),
        ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      // No automatic retry: a second attempt must come from the user.
      retry: (retryCount, error) => null,
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(
          visitor ? VisitorSession.new : _Session.new,
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Finder _button(String label) => find.widgetWithText(OutlinedButton, label);

void main() {
  setUp(_Session.reset);

  group('the account menu', () {
    testWidgets('shows the e-mail when there is no display name', (
      tester,
    ) async {
      _Session.reset(
        const AuthUser(
          id: 1,
          email: 'sans-nom@demo.ga',
          displayName: '',
          emailVerified: true,
        ),
      );
      await _open(tester, _Backend(), location: '/account');

      expect(find.text('sans-nom@demo.ga'), findsNWidgets(2));
    });

    testWidgets('counts the unread notifications on the entry', (tester) async {
      await _open(
        tester,
        _Backend(
          notifications: [
            _notification(1, 'Une'),
            _notification(2, 'Deux'),
            _notification(3, 'Lue', unread: false),
          ],
        ),
        location: '/account',
      );

      expect(find.widgetWithText(Badge, '2'), findsOneWidget);
    });

    testWidgets('has no badge when everything is read', (tester) async {
      await _open(
        tester,
        _Backend(notifications: [_notification(3, 'Lue', unread: false)]),
        location: '/account',
      );

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('every entry opens its screen', (tester) async {
      const entries = {
        'Mon panier': '/cart',
        'Notifications': '/notifications',
        'Mes favoris': '/account/favorites',
        'Mes alertes de prix': '/alerts',
        'Mes budgets': '/account/budgets',
        'Relevés de prix': '/contributions',
        'Assistant prix': '/assistant',
        'Aide et réclamations': '/support',
        'Ouvrir ma boutique': '/merchant/orders',
        'Mes rôles et candidatures': '/account/roles',
        'Profil et sécurité': '/account/profile',
        'Canaux de notification': '/account/channels',
      };
      for (final entry in entries.entries) {
        await _open(tester, _Backend(), location: '/account');
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        if (entry.value == '/notifications') {
          expect(find.text('Aucune notification.'), findsOneWidget);
        } else if (entry.value == '/account/profile') {
          expect(find.text('Mes informations'), findsOneWidget);
        } else {
          expect(find.text('vers ${entry.value}'), findsOneWidget);
        }
      }
    });

    testWidgets('invites a visitor to sign in', (tester) async {
      await _open(tester, _Backend(), location: '/account', visitor: true);

      expect(
        find.text('Connectez-vous pour gérer vos commandes et votre compte.'),
        findsOneWidget,
      );
    });

    testWidgets('signing out ends the session after a confirmation', (
      tester,
    ) async {
      await _open(tester, _Backend(), location: '/account');

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se déconnecter').last);
      await tester.pumpAndSettle();

      expect(_Session.loggedOut, 1);
    });

    testWidgets('signing out works even when the server cannot be reached', (
      tester,
    ) async {
      _Session.logoutFails = true;
      await _open(tester, _Backend(), location: '/account');

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se déconnecter').last);
      await tester.pumpAndSettle();

      expect(_Session.loggedOut, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('the profile', () {
    testWidgets('shows what is known about the user', (tester) async {
      await _open(tester, _Backend(), location: '/account/profile');

      expect(find.text('moi@demo.ga'), findsOneWidget);
      expect(find.text('Vérifier mon adresse e-mail'), findsNothing);
      expect(
        tester.widget<TextField>(_field('Nom affiché')).controller!.text,
        'Moi',
      );
      expect(
        tester.widget<TextField>(_field('Téléphone')).controller!.text,
        '+24106000000',
      );
      expect(
        tester.widget<TextField>(_field('Ville')).controller!.text,
        'Libreville',
      );
    });

    testWidgets('saves the changed profile', (tester) async {
      final api = await _open(tester, _Backend(), location: '/account/profile');

      await tester.enterText(_field('Nom affiché'), '  Moi Mbolo ');
      await tester.enterText(_field('Ville'), 'Port-Gentil');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(api.sent('PATCH', 'api/auth/me/').single.data, {
        'display_name': 'Moi Mbolo',
        'phone': '+24106000000',
        'city': 'Port-Gentil',
      });
      expect(find.text('Profil mis à jour.'), findsOneWidget);
    });

    testWidgets('shows why the profile was refused', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'PATCH api/auth/me/': 'Téléphone invalide.'}),
        location: '/account/profile',
      );

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Téléphone invalide.'), findsOneWidget);
      expect(find.text('Profil mis à jour.'), findsNothing);
    });
  });

  group('the e-mail check', () {
    setUp(
      () => _Session.reset(
        const AuthUser(
          id: 1,
          email: 'moi@demo.ga',
          displayName: 'Moi',
          emailVerified: false,
        ),
      ),
    );

    testWidgets('sends a code and confirms it', (tester) async {
      final api = await _open(tester, _Backend(), location: '/account/profile');

      await tester.tap(find.text('Vérifier mon adresse e-mail'));
      await tester.pumpAndSettle();
      expect(find.text('Vérifier votre adresse'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Code'), '123456');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/auth/email/verify/'), hasLength(1));
      expect(api.sent('POST', 'api/auth/email/verify/confirm/').single.data, {
        'code': '123456',
      });
      expect(find.text('Vérifier votre adresse'), findsNothing);
    });

    testWidgets('a wrong code keeps the dialog open with the reason', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(fail: {'POST api/auth/email/verify/confirm/': 'Code faux.'}),
        location: '/account/profile',
      );

      await tester.tap(find.text('Vérifier mon adresse e-mail'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Code'), '000000');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(find.text('Vérifier votre adresse'), findsOneWidget);
      expect(find.text('Code faux.'), findsOneWidget);
    });

    testWidgets('a new code can be asked for', (tester) async {
      final api = await _open(tester, _Backend(), location: '/account/profile');

      await tester.tap(find.text('Vérifier mon adresse e-mail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renvoyer'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/auth/email/verify/'), hasLength(2));
      expect(find.text('Un nouveau code a été envoyé.'), findsOneWidget);
    });

    testWidgets('a refused resend shows the reason in the dialog', (
      tester,
    ) async {
      await _open(
        tester,
        // The first code goes out; asking again is refused.
        _Backend(
          refuseAfterFirst: {
            'POST api/auth/email/verify/': 'Trop de codes demandés.',
          },
        ),
        location: '/account/profile',
      );
      await tester.tap(find.text('Vérifier mon adresse e-mail'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Renvoyer'));
      await tester.pumpAndSettle();

      expect(find.text('Vérifier votre adresse'), findsOneWidget);
      expect(find.text('Trop de codes demandés.'), findsOneWidget);
      expect(find.text('Un nouveau code a été envoyé.'), findsNothing);
    });

    testWidgets('"later" closes the dialog without verifying', (tester) async {
      final api = await _open(tester, _Backend(), location: '/account/profile');
      await tester.tap(find.text('Vérifier mon adresse e-mail'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      expect(find.text('Vérifier votre adresse'), findsNothing);
      expect(api.sent('POST', 'api/auth/email/verify/confirm/'), isEmpty);
    });

    testWidgets('no dialog opens when the code cannot be sent', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'POST api/auth/email/verify/': 'Service en panne.'}),
        location: '/account/profile',
      );

      await tester.tap(find.text('Vérifier mon adresse e-mail'));
      await tester.pumpAndSettle();

      expect(find.text('Vérifier votre adresse'), findsNothing);
      expect(find.text('Service en panne.'), findsOneWidget);
    });
  });

  group('the password', () {
    Future<FakeApi> openAndFill(WidgetTester tester, _Backend backend) async {
      final api = await _open(tester, backend, location: '/account/profile');
      await tester.enterText(_field('Mot de passe actuel'), 'Ancien!Passe-26');
      await tester.enterText(
        _field('Nouveau mot de passe'),
        'Nouveau!Passe-26',
      );
      await tester.enterText(_field('Confirmation'), 'Nouveau!Passe-26');
      return api;
    }

    testWidgets('is changed, then the device is signed out', (tester) async {
      final api = await openAndFill(tester, _Backend());

      await tester.tap(_button('Changer le mot de passe'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/auth/password/change/').single.data, {
        'current_password': 'Ancien!Passe-26',
        'new_password': 'Nouveau!Passe-26',
        'new_password_confirm': 'Nouveau!Passe-26',
      });
      expect(_Session.revoked, 1);
      expect(find.text('Page de connexion'), findsOneWidget);
    });

    testWidgets('a refusal keeps the session and says why', (tester) async {
      await openAndFill(
        tester,
        _Backend(
          fail: {'POST api/auth/password/change/': 'Mot de passe trop faible.'},
        ),
      );

      await tester.tap(_button('Changer le mot de passe'));
      await tester.pumpAndSettle();

      expect(_Session.revoked, 0);
      expect(find.text('Mot de passe trop faible.'), findsOneWidget);
      expect(find.text('Page de connexion'), findsNothing);
    });
  });

  group('the connected devices', () {
    testWidgets('lists them with their place', (tester) async {
      await _open(
        tester,
        _Backend(
          sessions: [
            _device('s1', 'Pixel 7', place: 'Libreville'),
            _device('s2', ''),
          ],
        ),
        location: '/account/profile',
      );

      expect(find.text('Pixel 7'), findsOneWidget);
      expect(find.text('Appareil'), findsOneWidget);
      expect(find.textContaining('· Libreville'), findsOneWidget);
    });

    testWidgets('signs one of them out', (tester) async {
      final api = await _open(
        tester,
        _Backend(sessions: [_device('s1', 'Pixel 7')]),
        location: '/account/profile',
      );

      await tester.tap(find.byTooltip('Déconnecter cet appareil'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/auth/sessions/s1/'), hasLength(1));
      expect(find.text('Appareil déconnecté.'), findsOneWidget);
    });

    testWidgets('says when the list cannot be loaded', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'GET api/auth/sessions/': 'Liste indisponible.'}),
        location: '/account/profile',
      );

      expect(find.text('Liste indisponible.'), findsOneWidget);
    });
  });

  group('closing the account', () {
    testWidgets('needs the password, kept exactly as typed', (tester) async {
      final api = await _open(tester, _Backend(), location: '/account/profile');

      await tester.tap(_button('Fermer mon compte'));
      await tester.pumpAndSettle();
      expect(find.text('Fermer définitivement le compte ?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, ' Mon!Passe ');
      await tester.tap(find.text('Fermer le compte'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/auth/me/').single.data, {
        'password': ' Mon!Passe ',
      });
      expect(_Session.revoked, 1);
      expect(find.text('Accueil'), findsOneWidget);
    });

    testWidgets('does nothing when it is cancelled', (tester) async {
      final api = await _open(tester, _Backend(), location: '/account/profile');

      await tester.tap(_button('Fermer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/auth/me/'), isEmpty);
      expect(_Session.revoked, 0);
    });

    testWidgets('a wrong password keeps the account open', (tester) async {
      await _open(
        tester,
        _Backend(fail: {'DELETE api/auth/me/': 'Mot de passe incorrect.'}),
        location: '/account/profile',
      );

      await tester.tap(_button('Fermer mon compte'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'mauvais');
      await tester.tap(find.text('Fermer le compte'));
      await tester.pumpAndSettle();

      expect(_Session.revoked, 0);
      expect(find.text('Mot de passe incorrect.'), findsOneWidget);
    });
  });

  group('the notifications', () {
    testWidgets('invite a visitor to sign in', (tester) async {
      await _open(
        tester,
        _Backend(),
        location: '/notifications',
        visitor: true,
      );

      expect(
        find.text('Connectez-vous pour accéder à cet espace.'),
        findsOneWidget,
      );
    });

    testWidgets('say so when there are none', (tester) async {
      await _open(tester, _Backend(), location: '/notifications');

      expect(find.text('Aucune notification.'), findsOneWidget);
    });

    testWidgets('tell read from unread', (tester) async {
      await _open(
        tester,
        _Backend(
          notifications: [
            _notification(1, 'Prix en baisse'),
            _notification(2, 'Commande livrée', unread: false),
          ],
        ),
        location: '/notifications',
      );

      expect(find.byIcon(Icons.mark_email_unread_outlined), findsOneWidget);
      expect(find.byIcon(Icons.drafts_outlined), findsOneWidget);
      expect(find.textContaining('Détail de Prix en baisse'), findsOneWidget);
    });

    testWidgets('an unread one is marked read when opened', (tester) async {
      final api = await _open(
        tester,
        _Backend(notifications: [_notification(1, 'Prix en baisse')]),
        location: '/notifications',
      );

      await tester.tap(find.text('Prix en baisse'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/notifications/1/read/'), hasLength(1));
    });

    testWidgets('a read one does nothing when opened', (tester) async {
      final api = await _open(
        tester,
        _Backend(notifications: [_notification(2, 'Livrée', unread: false)]),
        location: '/notifications',
      );

      await tester.tap(find.text('Livrée'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/notifications/2/read/'), isEmpty);
    });

    testWidgets('can all be marked read at once', (tester) async {
      final api = await _open(
        tester,
        _Backend(notifications: [_notification(1, 'Prix en baisse')]),
        location: '/notifications',
      );

      await tester.tap(find.byTooltip('Tout marquer comme lu'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/notifications/read_all/'), hasLength(1));
    });

    testWidgets('show the reason when marking fails', (tester) async {
      await _open(
        tester,
        _Backend(
          notifications: [_notification(1, 'Prix en baisse')],
          fail: {'POST api/notifications/read_all/': 'Action refusée.'},
        ),
        location: '/notifications',
      );

      await tester.tap(find.byTooltip('Tout marquer comme lu'));
      await tester.pumpAndSettle();

      expect(find.text('Action refusée.'), findsOneWidget);
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final api = await _open(
        tester,
        _Backend(notifications: [_notification(1, 'Prix en baisse')]),
        location: '/notifications',
      );
      final before = api.sent('GET', 'api/notifications/').length;

      await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(api.sent('GET', 'api/notifications/').length, greaterThan(before));
    });
  });
}
