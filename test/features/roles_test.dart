import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/models/auth_user.dart';
import 'package:frontend/features/roles/application_screen.dart';
import 'package:frontend/features/roles/applications_review_screens.dart';
import 'package:frontend/features/roles/my_roles_screen.dart';
import 'package:frontend/features/roles/roles_models.dart';

import '../support/fake_api.dart';

class _SessionAs extends AuthSessionController {
  _SessionAs(this.roles, this.userId);

  final List<String> roles;
  final int userId;

  @override
  Future<AuthUser?> build() async => AuthUser(
    id: userId,
    email: 'moi@demo.ga',
    displayName: 'Moi',
    emailVerified: true,
    roles: roles,
  );
}

Map<String, Object?> _requirement(
  String kind,
  String label, {
  bool expiry = false,
}) => {
  'kind': kind,
  'label': label,
  'help_text': '',
  'required': true,
  'expiry_required': expiry,
};

final _courierRequirements = [
  _requirement('identity', 'Pièce d’identité', expiry: true),
  _requirement('photo', 'Photo d’identité récente'),
  _requirement('address', 'Justificatif de domicile'),
  _requirement('criminal_record', 'Extrait de casier judiciaire'),
];

Map<String, Object?> _document(
  int id,
  String kind,
  String label, {
  String status = 'pending',
  String reason = '',
}) => {
  'id': id,
  'kind': kind,
  'kind_label': label,
  'status': status,
  'rejection_reason': reason,
  'expires_on': null,
  'download_url': '/api/roles/applications/5/documents/$id/file/',
  'created_at': '2026-11-18T10:00:00Z',
};

Map<String, Object?> _application({
  int id = 5,
  String role = 'courier',
  String status = 'draft',
  List<String> missing = const [],
  List<Map<String, Object?>>? documents,
  String reviewerMessage = '',
  int applicantId = 9,
  Map<String, Object?> details = const {
    'vehicle': 'bicycle',
    'phone': '+24101000000',
  },
}) => {
  'id': id,
  'role': role,
  'role_label': role == 'courier' ? 'Coursier' : 'Marchand',
  'status': status,
  'status_label': roleStatusLabels[status] ?? status,
  'details': details,
  'shop': null,
  'invited': false,
  'applicant': {
    'id': applicantId,
    'display_name': 'Awa Ndong',
    'email': 'awa@demo.ga',
    'phone': '+24107000000',
    'city': 'Libreville',
  },
  'reviewer_message': reviewerMessage,
  'rejection_reason': status == 'rejected' ? 'documents_invalid' : '',
  'rejection_label': status == 'rejected' ? 'Justificatifs non conformes' : '',
  'requirements': _courierRequirements,
  'missing': missing,
  'documents': documents ?? const <Map<String, Object?>>[],
  'submitted_at': status == 'draft' ? null : '2026-11-18T09:00:00Z',
  'decided_at': null,
  'created_at': '2026-11-17T09:00:00Z',
};

Map<String, Object?> _grant(
  int id,
  String role,
  String status, {
  String reason = '',
  String email = 'livreur@demo.ga',
}) => {
  'id': id,
  'role': role,
  'role_label': role == 'courier' ? 'Coursier' : 'Client',
  'status': status,
  'status_label': roleStatusLabels[status] ?? status,
  'status_reason': reason,
  'source': 'application',
  'user': {'id': 40 + id, 'email': email, 'display_name': 'Livreur $id'},
};

Future<FakeApi> _pump(
  WidgetTester tester,
  Widget screen,
  FakeReply Function(RequestOptions request) handler, {
  List<String> roles = const ['consumer'],
  int userId = 1,
}) async {
  final api = FakeApi(handler);
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(() => _SessionAs(roles, userId)),
      ],
      // A real router: the screens navigate with it. The destinations only
      // say where they were reached.
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (context, state) => screen),
            GoRoute(
              path: '/account/roles/applications/:id',
              builder: (context, state) =>
                  Scaffold(body: Text('Dossier ${state.pathParameters['id']}')),
            ),
            GoRoute(
              path: '/merchant/orders',
              builder: (context, state) =>
                  const Scaffold(body: Text('Espace marchand')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  group('models', () {
    test('a refused document does not count when another was sent', () {
      final application = RoleApplication.fromJson(
        _application(
          documents: [
            _document(1, 'photo', 'Photo', status: 'rejected', reason: 'Floue'),
            _document(2, 'photo', 'Photo'),
          ],
        ),
      );
      expect(application.documentFor('photo')!.id, 2);
      expect(application.documentFor('identity'), isNull);
    });

    test('only a refused document is returned when it is the only one', () {
      final application = RoleApplication.fromJson(
        _application(
          documents: [
            _document(1, 'photo', 'Photo', status: 'rejected', reason: 'Floue'),
          ],
        ),
      );
      expect(application.documentFor('photo')!.isRejected, isTrue);
    });

    test('editable states are the draft and the asked complement', () {
      bool editable(String status) =>
          RoleApplication.fromJson(_application(status: status)).isEditable;
      expect(editable('draft'), isTrue);
      expect(editable('info_requested'), isTrue);
      for (final status in [
        'submitted',
        'in_review',
        'approved',
        'rejected',
        'withdrawn',
      ]) {
        expect(editable(status), isFalse, reason: status);
      }
    });

    test('my roles find the open application of a role', () {
      final mine = MyRoles.fromJson({
        'grants': [_grant(1, 'consumer', 'active')],
        'applications': [
          _application(id: 1, status: 'rejected'),
          _application(id: 2, status: 'draft'),
        ],
      });
      expect(mine.openApplicationFor('courier')!.id, 2);
      expect(mine.latestApplicationFor('courier')!.id, 1);
      expect(mine.openApplicationFor('merchant'), isNull);
    });
  });

  group('my roles', () {
    FakeReply mine(List<Object?> grants, List<Object?> applications) =>
        ok({'grants': grants, 'applications': applications});

    testWidgets('a suspended role says why and cannot be applied for again', (
      tester,
    ) async {
      await _pump(
        tester,
        const MyRolesScreen(),
        (_) => mine([
          _grant(1, 'consumer', 'active'),
          _grant(2, 'courier', 'suspended', reason: 'Plainte en cours'),
        ], const []),
      );

      expect(find.text('Plainte en cours'), findsOneWidget);
      expect(find.text('SUSPENDU'), findsOneWidget);
      expect(find.text('Devenir coursier'), findsNothing);
      expect(find.text('Ouvrir ma boutique'), findsOneWidget);
    });

    testWidgets('a customer can apply to become a courier', (tester) async {
      final api = await _pump(
        tester,
        const MyRolesScreen(),
        (request) => request.method == 'POST'
            ? ok(_application(id: 7))
            : mine([_grant(1, 'consumer', 'active')], const []),
      );

      expect(find.text('Devenir coursier'), findsOneWidget);
      expect(find.textContaining('invite directement'), findsOneWidget);
      await tester.tap(find.text('Devenir coursier'));
      await tester.pumpAndSettle();
      expect(api.sent('POST', 'api/roles/applications/'), hasLength(1));
      expect(
        api.sent('POST', 'api/roles/applications/').single.data,
        containsPair('role', 'courier'),
      );
      // The new application opens, to send its documents.
      expect(find.text('Dossier 7'), findsOneWidget);
    });

    testWidgets('an application in progress hides the way to start another', (
      tester,
    ) async {
      await _pump(
        tester,
        const MyRolesScreen(),
        (_) => mine(
          [_grant(1, 'consumer', 'active')],
          [_application(status: 'submitted')],
        ),
      );

      expect(find.text('Devenir coursier'), findsNothing);
      expect(find.text('SOUMISE'), findsOneWidget);
    });
  });

  group('applicant', () {
    Future<FakeApi> open(
      WidgetTester tester,
      Map<String, Object?> application,
    ) => _pump(
      tester,
      const ApplicationScreen(applicationId: 5),
      (request) => ok(application),
    );

    testWidgets('lists what is asked and blocks sending while documents miss', (
      tester,
    ) async {
      await open(
        tester,
        _application(
          missing: ['identity', 'photo', 'address', 'criminal_record'],
        ),
      );

      expect(find.text('Pièce d’identité'), findsOneWidget);
      expect(find.text('Extrait de casier judiciaire'), findsOneWidget);
      expect(
        find.text('Il reste des justificatifs obligatoires à envoyer.'),
        findsOneWidget,
      );
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Envoyer ma candidature'),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('a complete application can be sent', (tester) async {
      final api = await open(
        tester,
        _application(
          documents: [
            _document(1, 'identity', 'Pièce d’identité'),
            _document(2, 'photo', 'Photo d’identité récente'),
            _document(3, 'address', 'Justificatif de domicile'),
            _document(4, 'criminal_record', 'Extrait de casier judiciaire'),
          ],
        ),
      );

      await tester.tap(find.text('Envoyer ma candidature'));
      await tester.pumpAndSettle();

      expect(
        api.sent('POST', 'api/roles/applications/5/submit/'),
        hasLength(1),
      );
    });

    testWidgets('without a vehicle the courier is asked for it first', (
      tester,
    ) async {
      await open(tester, _application(details: const {}));

      expect(find.textContaining('moyen de transport'), findsWidgets);
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Envoyer ma candidature'),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('a complement asked by the team is shown', (tester) async {
      await open(
        tester,
        _application(
          status: 'info_requested',
          reviewerMessage: 'Casier judiciaire trop ancien.',
          documents: [
            _document(
              4,
              'criminal_record',
              'Extrait de casier judiciaire',
              status: 'rejected',
              reason: 'Trop ancien',
            ),
          ],
        ),
      );

      expect(find.text('À compléter'), findsOneWidget);
      expect(find.text('Casier judiciaire trop ancien.'), findsOneWidget);
      expect(find.textContaining('Refusé : Trop ancien'), findsOneWidget);
      expect(
        find.byTooltip('Envoyer : Extrait de casier judiciaire'),
        findsOneWidget,
      );
    });

    testWidgets('a refusal shows its reason and cannot be edited', (
      tester,
    ) async {
      await open(
        tester,
        _application(
          status: 'rejected',
          reviewerMessage: 'Pièces non conformes.',
        ),
      );

      expect(
        find.text('Motif du refus : Justificatifs non conformes'),
        findsOneWidget,
      );
      expect(find.text('Envoyer ma candidature'), findsNothing);
      expect(find.text('Retirer ma candidature'), findsNothing);
    });

    testWidgets('an application under review can only be withdrawn', (
      tester,
    ) async {
      final api = await open(tester, _application(status: 'in_review'));

      expect(find.text('Envoyer ma candidature'), findsNothing);
      expect(find.byIcon(Icons.upload_file_outlined), findsNothing);
      await tester.tap(find.text('Retirer ma candidature'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Retirer'));
      await tester.pumpAndSettle();
      expect(
        api.sent('POST', 'api/roles/applications/5/withdraw/'),
        hasLength(1),
      );
    });
  });

  group('reviewer', () {
    final inReview = _application(
      status: 'in_review',
      documents: [
        _document(1, 'identity', 'Pièce d’identité'),
        _document(2, 'photo', 'Photo d’identité récente'),
        _document(3, 'address', 'Justificatif de domicile'),
        _document(4, 'criminal_record', 'Extrait de casier judiciaire'),
      ],
    );

    Future<FakeApi> review(
      WidgetTester tester,
      Map<String, Object?> application, {
      List<String> roles = const ['consumer', 'moderator'],
      int userId = 1,
    }) => _pump(
      tester,
      const ApplicationReviewScreen(applicationId: 5),
      (_) => ok(application),
      roles: roles,
      userId: userId,
    );

    testWidgets('shows the applicant and every document', (tester) async {
      await review(tester, inReview);

      expect(find.text('Awa Ndong'), findsOneWidget);
      expect(find.text('Vélo'), findsOneWidget);
      expect(find.text('Pièce d’identité'), findsOneWidget);
      expect(find.text('Accepter'), findsOneWidget);
      expect(find.text('Demander un complément'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
    });

    testWidgets('accepting asks for confirmation then approves', (
      tester,
    ) async {
      final api = await review(tester, inReview);

      await tester.tap(find.widgetWithText(FilledButton, 'Accepter'));
      await tester.pumpAndSettle();
      expect(find.text('Accepter cette candidature ?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Accepter'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        api.sent('POST', 'api/roles/applications/5/approve/'),
        hasLength(1),
      );
    });

    testWidgets('a submitted application must be taken in charge first', (
      tester,
    ) async {
      final api = await review(tester, _application(status: 'submitted'));

      expect(find.text('Accepter'), findsNothing);
      await tester.tap(find.text('Prendre en charge'));
      await tester.pumpAndSettle();
      expect(
        api.sent('POST', 'api/roles/applications/5/start_review/'),
        hasLength(1),
      );
    });

    testWidgets('nobody decides on their own application', (tester) async {
      await review(tester, inReview, userId: 9);

      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Refuser'), findsNothing);
      expect(find.textContaining('propre candidature'), findsOneWidget);
      expect(find.byTooltip('Refuser : Pièce d’identité'), findsNothing);
    });

    testWidgets('refusing a document asks why and sends the reason', (
      tester,
    ) async {
      final api = await review(tester, inReview);

      await tester.tap(find.byTooltip('Refuser : Pièce d’identité'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Photo illisible');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      final sent = api.sent(
        'POST',
        'api/roles/applications/5/documents/1/decide/',
      );
      expect(sent, hasLength(1));
      expect(sent.single.data, {
        'accepted': false,
        'reason': 'Photo illisible',
      });
    });

    testWidgets('asking for a complement needs a message', (tester) async {
      final api = await review(tester, inReview);

      await tester.tap(find.text('Demander un complément'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(
        api.sent('POST', 'api/roles/applications/5/request_info/'),
        isEmpty,
      );

      await tester.tap(find.text('Demander un complément'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Casier trop ancien');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(
        api.sent('POST', 'api/roles/applications/5/request_info/').single.data,
        {'message': 'Casier trop ancien'},
      );
    });

    testWidgets('refusing the application sends a reason and a message', (
      tester,
    ) async {
      final api = await review(tester, inReview);

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Refuser');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Pièces non conformes.');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/roles/applications/5/reject/').single.data, {
        'reason': 'documents_invalid',
        'message': 'Pièces non conformes.',
      });
    });

    testWidgets('a customer cannot open the review', (tester) async {
      await review(tester, inReview, roles: const ['consumer']);
      expect(
        find.text('Cet espace est réservé à un autre profil.'),
        findsOneWidget,
      );
      expect(find.text('Accepter'), findsNothing);
    });

    testWidgets('an admin reviews too', (tester) async {
      await review(tester, inReview, roles: const ['consumer', 'admin']);
      expect(find.text('Accepter'), findsOneWidget);
    });

    testWidgets('a closed application has nothing left to decide', (
      tester,
    ) async {
      await review(tester, _application(status: 'approved'));
      expect(find.text('Accepter'), findsNothing);
      expect(find.textContaining('plus aucune décision'), findsOneWidget);
    });
  });

  group('queue', () {
    testWidgets('lists the applications and filters by role', (tester) async {
      final api = await _pump(
        tester,
        const Scaffold(body: ApplicationsQueueScreen()),
        (_) => ok([_application(status: 'submitted')]),
        roles: const ['consumer', 'moderator'],
      );

      expect(find.text('Coursier'), findsWidgets);
      expect(find.textContaining('Awa Ndong'), findsOneWidget);
      await tester.tap(find.text('Marchands'));
      await tester.pumpAndSettle();
      expect(api.calls.last.queryParameters['role'], 'merchant');
    });

    testWidgets('says when nothing waits', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: ApplicationsQueueScreen()),
        (_) => ok(const <Object?>[]),
        roles: const ['consumer', 'moderator'],
      );
      expect(find.text('Aucune candidature à examiner.'), findsOneWidget);
    });
  });

  group('managed roles', () {
    FakeReply grants(_) => ok([
      _grant(3, 'courier', 'active'),
      _grant(4, 'courier', 'suspended', reason: 'Retards'),
    ]);

    testWidgets('a moderator suspends a role with a reason', (tester) async {
      final api = await _pump(
        tester,
        const RoleGrantsScreen(),
        grants,
        roles: const ['consumer', 'moderator'],
      );

      expect(find.text('Inviter'), findsNothing);
      expect(find.text('Modérateurs'), findsNothing);
      await tester.tap(find.byTooltip('Gérer ce rôle').first);
      await tester.pumpAndSettle();
      expect(find.text('Retirer définitivement'), findsNothing);
      await tester.tap(find.text('Suspendre'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Enquête en cours');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/roles/grants/3/suspend/').single.data, {
        'reason': 'Enquête en cours',
      });
    });

    testWidgets('a suspended role can be restored', (tester) async {
      final api = await _pump(
        tester,
        const RoleGrantsScreen(),
        grants,
        roles: const ['consumer', 'moderator'],
      );

      await tester.tap(find.byTooltip('Gérer ce rôle').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rétablir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/roles/grants/4/reactivate/'), hasLength(1));
    });

    testWidgets('only an admin can revoke and invite', (tester) async {
      final api = await _pump(
        tester,
        const RoleGrantsScreen(),
        grants,
        roles: const ['consumer', 'admin'],
      );

      expect(find.text('Modérateurs'), findsOneWidget);
      await tester.tap(find.byTooltip('Gérer ce rôle').first);
      await tester.pumpAndSettle();
      expect(find.text('Retirer définitivement'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inviter'));
      await tester.pumpAndSettle();
      final send = find.widgetWithText(FilledButton, 'Inviter');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'futur@demo.ga');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/roles/invitations/').single.data, {
        'email': 'futur@demo.ga',
        'role': 'support',
      });
    });
  });
}
