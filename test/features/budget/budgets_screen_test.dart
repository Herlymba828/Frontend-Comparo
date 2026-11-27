import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/formatters/price_formatter.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/budget/budgets_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _page(List<Map<String, Object?>> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

Map<String, Object?> _budget({
  int id = 1,
  String name = 'Courses du mois',
  String? plannedFor = '2026-12-05',
  bool withLines = true,
}) => {
  'id': id,
  'name': name,
  'planned_for': plannedFor,
  'estimate': {
    'current_total': '12500',
    'recent_average_total': '12000',
    'forecast_total': '13000',
    'limits': 'Estimation indicative.',
    'items': withLines
        ? [
            {
              'product': 3,
              'product_name': 'Riz 5kg',
              'quantity': '2',
              'unit': 'kg',
              'current_total': '9000',
              'recent_average_total': '8800',
              'recent_samples': 4,
              'forecast': {
                'date': '2026-12-05',
                'total': '9500',
                'lower': '9000',
                'upper': '10000',
              },
            },
            {
              'product': 4,
              'product_name': 'Huile',
              'quantity': '1',
              'unit': 'L',
              'current_total': '',
              'recent_average_total': '',
              'recent_samples': 0,
              'forecast': null,
            },
          ]
        : <Object?>[],
  },
};

const _failure = (
  status: 500,
  body: {
    'error': {'code': 'server_error', 'detail': 'Panne.'},
  },
);

final _budgetPath = RegExp(r'^api/analytics/budgets/(\d+)/$');

class _Backend {
  _Backend({this.budgets = const [], this.failWrites = false});

  final List<Map<String, Object?>> budgets;
  final bool failWrites;

  FakeReply answer(RequestOptions request) {
    final path = request.path;
    final isRead = request.method == 'GET';
    if (path == 'api/catalog/products/') {
      return ok(
        _page([
          {'id': 3, 'name': 'Riz 5kg'},
          {'id': 4, 'name': 'Huile'},
        ]),
      );
    }
    if (!isRead && failWrites) {
      return _failure;
    }
    if (path == 'api/analytics/budgets/') {
      return isRead
          ? ok(_page(budgets))
          : ok(_budget(id: 5, name: 'Nouveau', withLines: false));
    }
    final match = _budgetPath.firstMatch(path);
    if (match != null) {
      return request.method == 'DELETE'
          ? ok(<String, Object?>{})
          : ok(_budget(id: int.parse(match.group(1)!)));
    }
    return ok(<String, Object?>{});
  }
}

Future<FakeApi> _open(
  WidgetTester tester,
  _Backend backend, {
  bool visitor = false,
  String start = '/',
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeApi(backend.answer);
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const BudgetsScreen()),
      GoRoute(
        path: '/account/budgets/:id',
        builder: (context, state) =>
            BudgetScreen(budgetId: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(
          visitor ? VisitorSession.new : SignedInSession.new,
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Finder get _dialog => find.byType(AlertDialog);

Finder _inDialog(Finder finder) =>
    find.descendant(of: _dialog, matching: finder);

Future<void> _openNewEditor(WidgetTester tester) async {
  await tester.tap(find.text('Nouveau budget'));
  await tester.pumpAndSettle();
}

Future<void> _pickProduct(
  WidgetTester tester,
  String name, {
  int line = 0,
}) async {
  await tester.tap(find.text('Choisir un produit').at(line));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  group('the budget list', () {
    testWidgets('invites a visitor to sign in', (tester) async {
      await _open(tester, _Backend(), visitor: true);

      expect(
        find.text('Connectez-vous pour préparer vos budgets.'),
        findsOneWidget,
      );
    });

    testWidgets('says so when there is no budget', (tester) async {
      await _open(tester, _Backend());

      expect(find.text('Aucun budget pour le moment.'), findsOneWidget);
    });

    testWidgets('shows each budget with its size, date and total', (
      tester,
    ) async {
      await _open(
        tester,
        _Backend(
          budgets: [
            _budget(),
            _budget(id: 2, name: 'Fêtes', plannedFor: null, withLines: false),
          ],
        ),
      );

      expect(find.text('Courses du mois'), findsOneWidget);
      expect(find.text('2 produit(s) · pour le 05/12/2026'), findsOneWidget);
      expect(find.text(formatPrice('12500', 'XAF')), findsNWidgets(2));
      expect(find.text('Fêtes'), findsOneWidget);
      expect(find.text('0 produit(s)'), findsOneWidget);
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final api = await _open(tester, _Backend(budgets: [_budget()]));
      final before = api.sent('GET', 'api/analytics/budgets/').length;

      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        api.sent('GET', 'api/analytics/budgets/').length,
        greaterThan(before),
      );
    });

    testWidgets('opens a budget with its estimate', (tester) async {
      await _open(tester, _Backend(budgets: [_budget()]));

      await tester.tap(find.text('Courses du mois'));
      await tester.pumpAndSettle();

      expect(find.text('Budget'), findsOneWidget);
      expect(find.text('Achat prévu'), findsOneWidget);
      expect(find.text('05/12/2026'), findsOneWidget);
      expect(find.text('Estimation indicative.'), findsOneWidget);
      expect(find.text('Riz 5kg'), findsOneWidget);
      expect(find.text('2 kg'), findsOneWidget);
      expect(
        find.text('${formatPrice('8800', 'XAF')} (4 prix)'),
        findsOneWidget,
      );
    });
  });

  group('one budget', () {
    testWidgets('says what is unavailable instead of guessing', (tester) async {
      await _open(tester, _Backend(), start: '/account/budgets/1');

      // The second product has no offer, no average and no forecast.
      expect(find.text('Huile'), findsOneWidget);
      expect(find.text('Indisponible'), findsNWidgets(3));
      expect(
        find.text(
          '${formatPrice('9500', 'XAF')}, entre '
          '${formatPrice('9000', 'XAF')} et ${formatPrice('10000', 'XAF')}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('is deleted after a confirmation', (tester) async {
      final api = await _open(tester, _Backend(budgets: [_budget()]));
      await tester.tap(find.text('Courses du mois'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/analytics/budgets/1/'), hasLength(1));
      // Back on the list.
      expect(find.text('Mes budgets'), findsOneWidget);
    });

    testWidgets('is kept when the deletion is cancelled', (tester) async {
      final api = await _open(tester, _Backend(budgets: [_budget()]));
      await tester.tap(find.text('Courses du mois'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/analytics/budgets/1/'), isEmpty);
      expect(find.text('Budget'), findsOneWidget);
    });

    testWidgets('shows the error when the deletion fails', (tester) async {
      final api = await _open(
        tester,
        _Backend(budgets: [_budget()], failWrites: true),
      );
      await tester.tap(find.text('Courses du mois'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/analytics/budgets/1/'), hasLength(1));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Budget'), findsOneWidget);
    });

    testWidgets('is edited and saved', (tester) async {
      final api = await _open(tester, _Backend(), start: '/account/budgets/1');

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      expect(_inDialog(find.text('Modifier')), findsOneWidget);
      expect(find.text('Riz 5kg'), findsWidgets);
      await tester.enterText(
        _inDialog(find.widgetWithText(TextField, 'Nom')),
        'Fêtes de fin d’année',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final sent = api.sent('PATCH', 'api/analytics/budgets/1/');
      expect(sent, hasLength(1));
      final data = sent.single.data as Map;
      expect(data['name'], 'Fêtes de fin d’année');
      expect(data['planned_for'], '2026-12-05');
      expect(data['items'], [
        {'product_id': 3, 'quantity': '2'},
        {'product_id': 4, 'quantity': '1'},
      ]);
    });
  });

  group('the budget editor', () {
    testWidgets('needs a product', (tester) async {
      final api = await _open(tester, _Backend());
      await _openNewEditor(tester);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Donnez un nom et choisissez au moins un produit.'),
        findsOneWidget,
      );
      expect(api.sent('POST', 'api/analytics/budgets/'), isEmpty);
    });

    testWidgets('needs a name', (tester) async {
      final api = await _open(tester, _Backend());
      await _openNewEditor(tester);
      await _pickProduct(tester, 'Riz 5kg');
      await tester.enterText(
        _inDialog(find.widgetWithText(TextField, 'Nom')),
        '  ',
      );

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Donnez un nom et choisissez au moins un produit.'),
        findsOneWidget,
      );
      expect(api.sent('POST', 'api/analytics/budgets/'), isEmpty);
    });

    testWidgets('creates a budget from searched products, then opens it', (
      tester,
    ) async {
      final api = await _open(tester, _Backend());
      await _openNewEditor(tester);

      await _pickProduct(tester, 'Riz 5kg');
      await tester.enterText(
        _inDialog(find.widgetWithText(TextField, 'Qté')),
        '2,5',
      );
      await tester.tap(find.text('Ajouter un produit'));
      await tester.pumpAndSettle();
      await _pickProduct(tester, 'Huile', line: 0);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final sent = api.sent('POST', 'api/analytics/budgets/');
      expect(sent, hasLength(1));
      // No date: the client leaves the key out on creation.
      expect(sent.single.data, {
        'name': 'Courses du mois',
        'items': [
          {'product_id': 3, 'quantity': '2.5'},
          {'product_id': 4, 'quantity': '1'},
        ],
      });
      // Opened on the new budget.
      expect(find.text('Budget'), findsOneWidget);
    });

    testWidgets('searches the catalog with the typed words', (tester) async {
      final api = await _open(tester, _Backend());
      await _openNewEditor(tester);

      await tester.tap(find.text('Choisir un produit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Rechercher…'),
        ' riz ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final searches = api.sent('GET', 'api/catalog/products/');
      expect(searches.last.queryParameters['q'], 'riz');
    });

    testWidgets('a line can be removed unless it is the only one', (
      tester,
    ) async {
      await _open(tester, _Backend());
      await _openNewEditor(tester);
      IconButton remove(int at) => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline).at(at),
      );

      expect(remove(0).onPressed, isNull);
      await tester.tap(find.text('Ajouter un produit'));
      await tester.pumpAndSettle();
      expect(find.text('Choisir un produit'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Retirer').first);
      await tester.pumpAndSettle();

      expect(find.text('Choisir un produit'), findsOneWidget);
    });

    testWidgets('the purchase date can be set and removed', (tester) async {
      final api = await _open(tester, _Backend());
      await _openNewEditor(tester);

      await tester.tap(find.text('Date d’achat (facultatif)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Achat prévu le'), findsOneWidget);

      await tester.tap(find.byTooltip('Retirer la date'));
      await tester.pumpAndSettle();
      expect(find.text('Date d’achat (facultatif)'), findsOneWidget);

      // A date picked, then kept in what is sent.
      await tester.tap(find.text('Date d’achat (facultatif)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _pickProduct(tester, 'Riz 5kg');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final data =
          api.sent('POST', 'api/analytics/budgets/').single.data as Map;
      expect(data['planned_for'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    testWidgets('a cancelled date picker changes nothing', (tester) async {
      await _open(tester, _Backend());
      await _openNewEditor(tester);

      await tester.tap(find.text('Date d’achat (facultatif)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Date d’achat (facultatif)'), findsOneWidget);
    });

    testWidgets('stays open when the server refuses the budget', (
      tester,
    ) async {
      final api = await _open(tester, _Backend(failWrites: true));
      await _openNewEditor(tester);
      await _pickProduct(tester, 'Riz 5kg');

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(api.sent('POST', 'api/analytics/budgets/'), hasLength(1));
    });

    testWidgets('can be cancelled', (tester) async {
      final api = await _open(tester, _Backend());
      await _openNewEditor(tester);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(api.sent('POST', 'api/analytics/budgets/'), isEmpty);
    });
  });
}
