import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recommendations/recommendations.dart';

import '../support/fake_api.dart';

Map<String, Object?> _evidence(String role, String product, String amount) => {
  'role': role,
  'product_id': role == 'recommended' ? 9 : 4,
  'product_name': product,
  'merchant_id': 31,
  'merchant_name': 'Mbolo Louis',
  'amount': amount,
  'currency': 'XAF',
  'quantity': '5',
  'unit_symbol': 'kg',
  'observed_at': DateTime.now()
      .subtract(const Duration(hours: 3))
      .toUtc()
      .toIso8601String(),
  'trust': {'explanation': 'Relevé il y a 3 h, vérifié par un modérateur.'},
};

Map<String, Object?> _substitute() => {
  'id': 'substitute:4:9',
  'kind': 'cheaper_substitute',
  'reason': {
    'code': 'same_use_cheaper_per_unit',
    'text': 'Produit proche, 20 % moins cher au kg chez Mbolo Louis.',
  },
  'confidence': {'level': 'high', 'label': 'Confiance élevée'},
  'freshness': {'level': 'fresh', 'label': 'Très récent'},
  'evidence': [
    _evidence('current_best', 'Riz parfumé 5 kg', '5000.00'),
    _evidence('recommended', 'Riz Gabon Or 5 kg', '4000.00'),
  ],
  'saving': {'amount': '1000.00', 'currency': 'XAF'},
  'actions': [
    {'type': 'open_product', 'product_id': 9},
  ],
};

Future<void> _pump(WidgetTester tester, FakeApi api, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [jsonApiProvider.overrideWithValue(api.jsonApi)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a recommendation without the recommended price is refused', () {
    final json = _substitute()
      ..['evidence'] = [_evidence('current_best', 'Riz', '5000.00')];
    expect(
      () => SubstituteRecommendation.fromJson(json),
      throwsFormatException,
    );
  });

  testWidgets('a cheaper substitute shows its price, saving and reason', (
    tester,
  ) async {
    final api = FakeApi(
      (_) => ok({
        'results': [_substitute()],
        'insufficient_data': null,
      }),
    );
    await _pump(
      tester,
      api,
      const SubstituteRecommendationsSection(productId: 4),
    );

    expect(find.text('Plus économique'), findsOneWidget);
    expect(find.text('Riz Gabon Or 5 kg'), findsOneWidget);
    expect(find.text('4 000 FCFA'), findsOneWidget);
    expect(find.text('−1 000 FCFA'), findsOneWidget);
    expect(find.textContaining('20 % moins cher'), findsOneWidget);
    expect(
      api.sent('GET', 'api/recommendations/products/4/substitutes/'),
      hasLength(1),
    );

    await tester.tap(find.text('Pourquoi ?'));
    await tester.pumpAndSettle();
    expect(find.text('Pourquoi cette suggestion ?'), findsOneWidget);
    expect(find.text('Comparé à : Riz parfumé 5 kg'), findsOneWidget);
    expect(find.text('Suggéré : Riz Gabon Or 5 kg'), findsOneWidget);
  });

  testWidgets('without enough data the section stays hidden', (tester) async {
    await _pump(
      tester,
      FakeApi(
        (_) => ok({
          'results': <Object?>[],
          'insufficient_data': {'code': 'no_cheaper_substitute'},
        }),
      ),
      const SubstituteRecommendationsSection(productId: 4),
    );
    expect(find.text('Plus économique'), findsNothing);
  });

  testWidgets('an API error leaves the page without the section', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeApi((_) => (status: 503, body: {'detail': 'indisponible'})),
      const SubstituteRecommendationsSection(productId: 4),
    );
    expect(find.text('Plus économique'), findsNothing);
  });

  testWidgets('the list advice names the shop, total and reason', (
    tester,
  ) async {
    final api = FakeApi((request) {
      if (request.path == 'api/recommendations/cart/') {
        return ok({
          'recommended': {
            'kind': 'single',
            'merchants': [
              {'merchant_name': 'Mbolo Louis'},
            ],
            'total': '23450.00',
            'reason': {'text': 'Toute votre liste est disponible chez Mbolo.'},
          },
        });
      }
      return ok({'id': 1, 'items': <Object?>[], 'total': '0.00'});
    });
    await _pump(tester, api, const CartAdviceCard());

    expect(find.text('Notre conseil'), findsOneWidget);
    expect(find.text('Tout chez Mbolo Louis'), findsOneWidget);
    expect(find.text('23 450 FCFA'), findsOneWidget);
  });

  testWidgets('no advice without a verified shop for the list', (tester) async {
    final api = FakeApi((request) {
      if (request.path == 'api/recommendations/cart/') {
        return ok({
          'recommended': null,
          'insufficient_data': {'code': 'no_offer'},
        });
      }
      return ok({'id': 1, 'items': <Object?>[], 'total': '0.00'});
    });
    await _pump(tester, api, const CartAdviceCard());
    expect(find.text('Notre conseil'), findsNothing);
  });
}
