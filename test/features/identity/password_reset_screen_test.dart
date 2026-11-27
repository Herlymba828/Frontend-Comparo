import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/identity/data/auth_repository.dart';
import 'package:frontend/features/identity/data/auth_token_storage.dart';
import 'package:frontend/features/identity/password_reset_screen.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_api.dart';

class _MemoryTokens implements AuthTokenStorage {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

const _resetPath = 'api/auth/password/reset/';
const _confirmPath = 'api/auth/password/reset/confirm/';

Future<FakeApi> _open(
  WidgetTester tester, {
  FakeReply Function(RequestOptions request)? handler,
  String initialEmail = '',
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeApi(handler ?? (request) => ok(<String, Object?>{}));
  final repository = AuthRepository(
    Dio(BaseOptions(baseUrl: 'https://api.example.test/'))
      ..httpClientAdapter = api,
    _MemoryTokens(),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            PasswordResetScreen(initialEmail: initialEmail),
      ),
      GoRoute(
        path: '/auth',
        // A Scaffold, like the real page: the confirmation snack bar needs one.
        builder: (context, state) =>
            const Scaffold(body: Text('Page de connexion')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _askForCode(
  WidgetTester tester, {
  String email = 'a@demo.ga',
}) async {
  await tester.enterText(_field('Adresse e-mail'), email);
  await tester.tap(find.text('Recevoir un code'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the e-mail is refused when it is empty or has no @', (
    tester,
  ) async {
    final api = await _open(tester);

    await tester.tap(find.text('Recevoir un code'));
    await tester.pumpAndSettle();
    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);

    await tester.enterText(_field('Adresse e-mail'), 'pas-une-adresse');
    await tester.tap(find.text('Recevoir un code'));
    await tester.pumpAndSettle();

    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('asking for a code sends the trimmed e-mail and shows the code '
      'fields', (tester) async {
    final api = await _open(tester, initialEmail: '  client@demo.ga ');

    await tester.tap(find.text('Recevoir un code'));
    await tester.pumpAndSettle();

    final sent = api.sent('POST', _resetPath);
    expect(sent, hasLength(1));
    expect((sent.single.data as Map)['email'], 'client@demo.ga');
    expect(find.textContaining('code à 6 chiffres'), findsOneWidget);
    expect(_field('Code reçu'), findsOneWidget);
    expect(_field('Nouveau mot de passe'), findsOneWidget);
    expect(find.text('Changer mon mot de passe'), findsOneWidget);
  });

  testWidgets('a refused request shows the error and stays on the first step', (
    tester,
  ) async {
    await _open(
      tester,
      handler: (request) => (
        status: 429,
        body: {
          'error': {'code': 'throttled', 'detail': 'Trop de demandes.'},
        },
      ),
    );

    await _askForCode(tester);

    expect(_field('Code reçu'), findsNothing);
    expect(find.text('Recevoir un code'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final errors = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.style?.color == AppTheme.light.colorScheme.error,
    );
    expect(errors, findsOneWidget);
  });

  testWidgets('the new password is checked before anything is sent', (
    tester,
  ) async {
    final api = await _open(tester);
    await _askForCode(tester);
    api.calls.clear();

    await tester.enterText(_field('Code reçu'), '12');
    await tester.enterText(_field('Nouveau mot de passe'), 'court');
    await tester.enterText(_field('Confirmer le mot de passe'), 'autre');
    await tester.tap(find.text('Changer mon mot de passe'));
    await tester.pumpAndSettle();

    expect(find.text('Le code contient 6 chiffres.'), findsOneWidget);
    expect(
      find.text('Le mot de passe doit contenir au moins 8 caractères.'),
      findsOneWidget,
    );
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(api.calls, isEmpty);
  });

  testWidgets('a valid change sends the code and returns to the sign-in', (
    tester,
  ) async {
    final api = await _open(tester);
    await _askForCode(tester, email: 'client@demo.ga');

    await tester.enterText(_field('Code reçu'), '123456');
    await tester.enterText(_field('Nouveau mot de passe'), 'Nouveau!Passe-26');
    await tester.enterText(
      _field('Confirmer le mot de passe'),
      'Nouveau!Passe-26',
    );
    await tester.tap(find.text('Changer mon mot de passe'));
    await tester.pumpAndSettle();

    final sent = api.sent('POST', _confirmPath);
    expect(sent, hasLength(1));
    expect(sent.single.data, {
      'email': 'client@demo.ga',
      'code': '123456',
      'new_password': 'Nouveau!Passe-26',
    });
    expect(find.text('Page de connexion'), findsOneWidget);
    expect(find.textContaining('Mot de passe modifié'), findsOneWidget);
  });

  testWidgets('a wrong code keeps the user on the form with the error', (
    tester,
  ) async {
    await _open(
      tester,
      handler: (request) => request.path == _confirmPath
          ? (
              status: 400,
              body: {
                'error': {'code': 'invalid', 'detail': 'Code invalide.'},
              },
            )
          : ok(<String, Object?>{}),
    );
    await _askForCode(tester);

    await tester.enterText(_field('Code reçu'), '000000');
    await tester.enterText(_field('Nouveau mot de passe'), 'Nouveau!Passe-26');
    await tester.enterText(
      _field('Confirmer le mot de passe'),
      'Nouveau!Passe-26',
    );
    await tester.tap(find.text('Changer mon mot de passe'));
    await tester.pumpAndSettle();

    expect(find.text('Page de connexion'), findsNothing);
    expect(_field('Code reçu'), findsOneWidget);
  });

  testWidgets('the password can be shown or hidden', (tester) async {
    await _open(tester);
    await _askForCode(tester);

    EditableText password() => tester.widget<EditableText>(
      find.descendant(
        of: _field('Nouveau mot de passe'),
        matching: find.byType(EditableText),
      ),
    );

    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Afficher le mot de passe'));
    await tester.pump();
    expect(password().obscureText, isFalse);
    expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
  });

  testWidgets('changing the address goes back to the first step', (
    tester,
  ) async {
    await _open(tester);
    await _askForCode(tester);
    await tester.enterText(_field('Code reçu'), '123456');

    await tester.tap(find.text('Changer d’adresse ou renvoyer un code'));
    await tester.pumpAndSettle();

    expect(_field('Code reçu'), findsNothing);
    expect(find.text('Recevoir un code'), findsOneWidget);
  });
}
