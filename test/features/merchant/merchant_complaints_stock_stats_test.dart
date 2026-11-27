import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/formatters/price_formatter.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/merchant/merchant_complaints_screen.dart';
import 'package:frontend/features/merchant/merchant_shell.dart';
import 'package:frontend/features/merchant/merchant_stats_screen.dart';
import 'package:frontend/features/merchant/merchant_stock_screen.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _page(List<Object?> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

/// Answers from [routes] ("METHOD path"), and refuses what is in [fail].
class _Backend {
  _Backend({this.routes = const {}, this.fail = const {}});

  final Map<String, Object?> routes;
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
    return ok(routes[key] ?? <String, Object?>{'results': <Object?>[]});
  }
}

ProviderScope _scope(
  FakeApi api,
  Widget child, {
  AuthSessionController Function()? session,
}) => ProviderScope(
  // No automatic retry: a second attempt must come from the user.
  retry: (retryCount, error) => null,
  overrides: [
    jsonApiProvider.overrideWithValue(api.jsonApi),
    authSessionProvider.overrideWith(session ?? MerchantSession.new),
  ],
  child: child,
);

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _bigWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// ── Complaints ──────────────────────────────────────────────────────────────

Map<String, Object?> _complaint({
  String status = 'filed',
  bool open = true,
  String response = '',
  String? respondedAt,
}) => {
  'id': 4,
  'complaint_number': 'CPL-004',
  'subject': 'Prix affiché différent',
  'complaint_type': 'wrong_price',
  'status': status,
  'filed_at': '2026-11-19T08:00:00Z',
  'is_open': open,
  'description': 'Le prix en rayon n’est pas celui de la caisse.',
  'merchant_response': response,
  'responded_at': respondedAt,
};

Future<FakeApi> _openComplaints(
  WidgetTester tester,
  _Backend backend, {
  AuthSessionController Function()? session,
  String start = '/',
}) async {
  _bigWindow(tester);
  final api = FakeApi(backend.answer);
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: MerchantComplaintsScreen()),
      ),
      GoRoute(
        path: '/merchant/complaints/:id',
        builder: (context, state) => MerchantComplaintScreen(
          complaintId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    _scope(
      api,
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      session: session,
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Map<String, Object?> _attachment({bool mine = true}) => {
  'id': 1,
  'description': 'Ticket de caisse',
  'download_url': 'api/disputes/4/attachments/1/download/',
  'is_mine': mine,
  'created_at': '2026-11-19T09:00:00Z',
};

void main() {
  group('the complaints against the shop', () {
    testWidgets('say so when there are none', (tester) async {
      await _openComplaints(tester, _Backend());

      expect(
        find.text('Aucune réclamation contre votre boutique.'),
        findsOneWidget,
      );
    });

    testWidgets('are listed and can be opened', (tester) async {
      await _openComplaints(
        tester,
        _Backend(
          routes: {
            'GET api/disputes/': _page([_complaint()]),
            'GET api/disputes/4/': _complaint(),
          },
        ),
      );

      expect(find.text('Prix affiché différent'), findsOneWidget);
      expect(
        find.textContaining('Prix incorrect ou trompeur · 19/11/2026'),
        findsOneWidget,
      );
      await tester.tap(find.text('Prix affiché différent'));
      await tester.pumpAndSettle();

      expect(find.text('CPL-004'), findsOneWidget);
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final api = await _openComplaints(
        tester,
        _Backend(
          routes: {
            'GET api/disputes/': _page([_complaint()]),
          },
        ),
      );
      final before = api.sent('GET', 'api/disputes/').length;

      await _pullToRefresh(tester);

      expect(api.sent('GET', 'api/disputes/').length, greaterThan(before));
    });

    testWidgets('show why they could not be loaded, and can be retried', (
      tester,
    ) async {
      final api = await _openComplaints(
        tester,
        _Backend(fail: {'GET api/disputes/': 'Réclamations indisponibles.'}),
      );

      expect(find.text('Réclamations indisponibles.'), findsOneWidget);
      final before = api.sent('GET', 'api/disputes/').length;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(api.sent('GET', 'api/disputes/').length, greaterThan(before));
    });
  });

  group('one complaint against the shop', () {
    Future<FakeApi> open(
      WidgetTester tester, {
      Map<String, Object?>? complaint,
      List<Object?> attachments = const [],
      Map<String, String> fail = const {},
    }) => _openComplaints(
      tester,
      _Backend(
        routes: {
          'GET api/disputes/4/': complaint ?? _complaint(),
          'GET api/disputes/4/attachments/': _page(attachments),
        },
        fail: fail,
      ),
      start: '/merchant/complaints/4',
    );

    testWidgets('shows what was reported', (tester) async {
      await open(tester);

      expect(find.text('CPL-004'), findsOneWidget);
      expect(find.text('Prix incorrect ou trompeur'), findsOneWidget);
      expect(find.text('Prix affiché différent'), findsOneWidget);
      expect(
        find.text('Le prix en rayon n’est pas celui de la caisse.'),
        findsOneWidget,
      );
    });

    testWidgets('is turned away from anyone who is not a merchant', (
      tester,
    ) async {
      await _openComplaints(
        tester,
        _Backend(),
        session: SignedInSession.new,
        start: '/merchant/complaints/4',
      );

      expect(
        find.text('Cet espace est réservé à un autre profil.'),
        findsOneWidget,
      );
    });

    testWidgets('an open one takes the shop’s version of the facts', (
      tester,
    ) async {
      final api = await open(tester);

      expect(find.text('Votre version des faits'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Étiquette périmée. ');
      await tester.tap(find.text('Envoyer au service client'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/disputes/4/respond/').single.data, {
        'response': 'Étiquette périmée.',
      });
      expect(find.text('Réponse transmise au service client.'), findsOneWidget);
    });

    testWidgets('an empty answer is not sent', (tester) async {
      final api = await open(tester);

      await tester.tap(find.text('Envoyer au service client'));
      await tester.pumpAndSettle();

      expect(find.text('Écrivez votre réponse.'), findsOneWidget);
      expect(api.sent('POST', 'api/disputes/4/respond/'), isEmpty);
    });

    testWidgets('a refused answer shows why', (tester) async {
      await open(
        tester,
        fail: {'POST api/disputes/4/respond/': 'Réclamation déjà tranchée.'},
      );

      await tester.enterText(find.byType(TextField), 'Réponse');
      await tester.tap(find.text('Envoyer au service client'));
      await tester.pumpAndSettle();

      expect(find.text('Réclamation déjà tranchée.'), findsOneWidget);
    });

    testWidgets('an answered one can still be completed', (tester) async {
      await open(
        tester,
        complaint: _complaint(
          response: 'Nous vérifions.',
          respondedAt: '2026-11-20T10:00:00Z',
        ),
      );

      expect(find.text('Nous vérifions.'), findsOneWidget);
      expect(find.textContaining('Envoyée le 20/11/2026'), findsOneWidget);
      expect(find.text('Compléter ou corriger votre réponse'), findsOneWidget);
    });

    testWidgets('a closed one without an answer says so, and has no form', (
      tester,
    ) async {
      await open(tester, complaint: _complaint(status: 'closed', open: false));

      expect(
        find.text('Aucune réponse : la réclamation est close.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Envoyer au service client'), findsNothing);
    });

    testWidgets('a closed one keeps the answer that was given', (tester) async {
      await open(
        tester,
        complaint: _complaint(
          status: 'closed',
          open: false,
          response: 'Erreur corrigée.',
        ),
      );

      expect(find.text('Erreur corrigée.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('lists the pieces of the file', (tester) async {
      await open(
        tester,
        attachments: [_attachment(), _attachment(mine: false)],
      );

      expect(find.text('Pièces du dossier'), findsOneWidget);
      expect(find.text('Ticket de caisse'), findsNWidgets(2));
      expect(find.textContaining('Ajoutée par vous'), findsOneWidget);
      expect(find.textContaining('Ajoutée par l’autre partie'), findsOneWidget);
      expect(find.byTooltip('Ajouter une pièce'), findsOneWidget);
    });

    testWidgets('a closed file has no piece and no way to add one', (
      tester,
    ) async {
      await open(tester, complaint: _complaint(status: 'closed', open: false));

      expect(find.text('Aucune pièce.'), findsOneWidget);
      expect(find.byTooltip('Ajouter une pièce'), findsNothing);
    });

    testWidgets('an open file invites to add evidence', (tester) async {
      await open(tester);

      expect(
        find.textContaining('Ticket de caisse, photo de l’étiquette'),
        findsOneWidget,
      );
    });

    testWidgets('shows why the complaint could not be loaded', (tester) async {
      await open(tester, fail: {'GET api/disputes/4/': 'Dossier introuvable.'});

      expect(find.text('Dossier introuvable.'), findsOneWidget);
    });
  });

  // ── Stock ─────────────────────────────────────────────────────────────────

  Map<String, Object?> shop({bool verified = true}) => {
    'id': 7,
    'name': 'Chez Mbolo',
    'description': '',
    'phone': '',
    'email': '',
    'status': verified ? 'active' : 'pending',
    'is_active': true,
    'is_verified': verified,
  };

  Map<String, Object?> line({
    int id = 1,
    String product = 'Riz 5kg',
    String status = 'limited',
    String? quantity = '12.000',
  }) => {
    'id': id,
    'product': 3,
    'product_name': product,
    'status': status,
    'quantity_available': quantity,
  };

  group('the stock', () {
    Future<FakeApi> openStock(
      WidgetTester tester, {
      List<Object?> lines = const [],
      bool verified = true,
      Map<String, String> fail = const {},
    }) async {
      _bigWindow(tester);
      final api = FakeApi(
        _Backend(
          routes: {
            'GET api/merchants/me/': shop(verified: verified),
            'GET api/availability/': _page(lines),
            'GET api/catalog/products/': _page([
              {'id': 3, 'name': 'Riz 5kg'},
            ]),
          },
          fail: fail,
        ).answer,
      );
      await tester.pumpWidget(
        _scope(
          api,
          MaterialApp(
            theme: AppTheme.light,
            home: MerchantShell(
              location: '/merchant/stock',
              child: ShopPage(
                builder: (shop) => MerchantStockScreen(shopId: shop.id),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('says so when nothing is declared', (tester) async {
      await openStock(tester);

      expect(find.text('Aucune disponibilité déclarée.'), findsOneWidget);
    });

    testWidgets('lists the products with their quantity', (tester) async {
      await openStock(
        tester,
        lines: [
          line(),
          line(id: 2, product: 'Huile', quantity: null),
        ],
      );

      expect(find.text('Riz 5kg'), findsOneWidget);
      expect(find.text('Quantité : 12.000'), findsOneWidget);
      expect(find.text('Huile'), findsOneWidget);
      expect(find.textContaining('Quantité :'), findsOneWidget);
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final api = await openStock(tester, lines: [line()]);
      final before = api.sent('GET', 'api/availability/').length;

      await _pullToRefresh(tester);

      expect(api.sent('GET', 'api/availability/').length, greaterThan(before));
    });

    testWidgets('shows why it could not be loaded', (tester) async {
      await openStock(
        tester,
        fail: {'GET api/availability/': 'Stock indisponible.'},
      );

      expect(find.text('Stock indisponible.'), findsOneWidget);
    });

    testWidgets('a product is declared with its state and quantity', (
      tester,
    ) async {
      final api = await openStock(tester);

      await tester.tap(find.text('Déclarer un stock'));
      await tester.pumpAndSettle();
      expect(find.text('Disponibilité'), findsOneWidget);
      await tester.tap(find.text('Choisir un produit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riz 5kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rupture').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Quantité disponible (facultatif)'),
        '2,5',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final data = api.sent('POST', 'api/availability/').single.data as Map;
      expect(data['status'], 'unavailable');
      expect(data['quantity_available'], '2.5');
      expect(data['product_id'], 3);
      expect(data['merchant_id'], 7);
    });

    testWidgets('needs a product', (tester) async {
      final api = await openStock(tester);

      await tester.tap(find.text('Déclarer un stock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Choisissez un produit.'), findsOneWidget);
      expect(api.sent('POST', 'api/availability/'), isEmpty);
    });

    testWidgets('a declared line is edited, and may lose its quantity', (
      tester,
    ) async {
      final api = await openStock(tester, lines: [line()]);

      await tester.tap(find.text('Riz 5kg'));
      await tester.pumpAndSettle();
      expect(find.text('Disponibilité'), findsOneWidget);
      expect(find.widgetWithText(TextField, '12.000'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '12.000'), '');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final data = api.sent('PATCH', 'api/availability/1/').single.data as Map;
      expect(data['status'], 'limited');
      expect(data.containsKey('quantity_available'), isTrue);
      expect(data['quantity_available'], isNull);
    });

    testWidgets('a refused declaration keeps the dialog and says why', (
      tester,
    ) async {
      await openStock(
        tester,
        lines: [line()],
        fail: {'PATCH api/availability/1/': 'Stock verrouillé.'},
      );

      await tester.tap(find.text('Riz 5kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Stock verrouillé.'), findsOneWidget);
      expect(find.text('Disponibilité'), findsOneWidget);
    });

    testWidgets('a dialog can be cancelled', (tester) async {
      final api = await openStock(tester, lines: [line()]);

      await tester.tap(find.text('Riz 5kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(api.sent('PATCH', 'api/availability/1/'), isEmpty);
    });

    testWidgets('a shop awaiting verification cannot edit a line', (
      tester,
    ) async {
      await openStock(tester, lines: [line()], verified: false);

      await tester.tap(find.text('Riz 5kg'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('en attente de vérification'), findsWidgets);
    });
  });

  // ── Statistics ────────────────────────────────────────────────────────────

  Map<String, Object?> stats({bool empty = false}) => {
    'days': 30,
    'orders': 4,
    'sold_orders': 3,
    'cancellation_rate': 25.0,
    'revenue': '9900.00',
    'refunded': '1000.00',
    'average_basket': '3300.00',
    'daily': empty
        ? <Object?>[]
        : [
            {'date': '2026-11-19T00:00:00Z', 'orders': 2, 'revenue': '6600.00'},
            {'date': '2026-11-20T00:00:00Z', 'orders': 1, 'revenue': '3300.00'},
          ],
    'top_products': empty
        ? <Object?>[]
        : [
            {
              'product_name': 'Riz complet',
              'quantity': '4',
              'revenue': '6600.00',
            },
          ],
  };

  group('the shop statistics', () {
    Future<FakeApi> openStats(
      WidgetTester tester, {
      Map<String, Object?>? data,
      AuthSessionController Function()? session,
      Map<String, String> fail = const {},
    }) async {
      _bigWindow(tester);
      final api = FakeApi(
        _Backend(
          routes: {'GET api/merchants/me/stats/': data ?? stats()},
          fail: fail,
        ).answer,
      );
      await tester.pumpWidget(
        _scope(
          api,
          MaterialApp(theme: AppTheme.light, home: const MerchantStatsScreen()),
          session: session,
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('are turned away from anyone who is not a merchant', (
      tester,
    ) async {
      await openStats(tester, session: SignedInSession.new);

      expect(
        find.text('Cet espace est réservé à un autre profil.'),
        findsOneWidget,
      );
    });

    testWidgets('sum up the sales of the last 30 days', (tester) async {
      final api = await openStats(tester);

      expect(
        api
            .sent('GET', 'api/merchants/me/stats/')
            .single
            .queryParameters['days'],
        30,
      );
      expect(find.text(formatPrice('9900.00', 'XAF')), findsOneWidget);
      expect(find.text(formatPrice('1000.00', 'XAF')), findsOneWidget);
      expect(find.text('3 sur 4'), findsOneWidget);
      expect(find.text(formatPrice('3300.00', 'XAF')), findsNWidgets(2));
      expect(find.text('25.0 %'), findsOneWidget);
    });

    testWidgets('show each day, scaled to the best one', (tester) async {
      await openStats(tester);

      expect(find.text('19/11'), findsOneWidget);
      expect(find.text('20/11'), findsOneWidget);
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .map((bar) => bar.value)
          .toList();
      expect(bars, [1.0, 0.5]);
    });

    testWidgets('name the best sellers', (tester) async {
      await openStats(tester);

      expect(find.text('Riz complet'), findsOneWidget);
    });

    testWidgets('say so when the period had no sale', (tester) async {
      await openStats(tester, data: stats(empty: true));

      expect(find.text('Aucune vente sur la période.'), findsNWidgets(2));
    });

    testWidgets('can look at another period', (tester) async {
      final api = await openStats(tester);

      await tester.tap(find.text('7 jours'));
      await tester.pumpAndSettle();

      expect(
        api.sent('GET', 'api/merchants/me/stats/').last.queryParameters['days'],
        7,
      );
    });

    testWidgets('show why they could not be loaded, and can retry', (
      tester,
    ) async {
      final api = await openStats(
        tester,
        fail: {'GET api/merchants/me/stats/': 'Statistiques indisponibles.'},
      );

      expect(find.text('Statistiques indisponibles.'), findsOneWidget);
      final before = api.sent('GET', 'api/merchants/me/stats/').length;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(
        api.sent('GET', 'api/merchants/me/stats/').length,
        greaterThan(before),
      );
    });

    test('a bare answer reads as zeros over 30 days', () {
      final empty = ShopStats.fromJson(const {});

      expect(empty.days, 30);
      expect(empty.orders, 0);
      expect(empty.cancellationRate, 0);
      expect(empty.revenue, '0');
      expect(empty.daily, isEmpty);
      expect(empty.topProducts, isEmpty);
    });
  });
}
