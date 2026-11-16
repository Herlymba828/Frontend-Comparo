import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/comparison/alternatives.dart';

import '../support/fake_api.dart';

Map<String, Object?> _alternative(int id, String name, String kind) => {
  'equivalence_id': id,
  'match_kind': kind,
  'notes': kind == 'substitute' ? 'Même usage, autre marque' : '',
  'product': productJson(100 + id, name, price: '700.00'),
};

Future<void> _pump(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [jsonApiProvider.overrideWithValue(api.jsonApi)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AlternativesSection(productId: 4)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('an alternative reads its kind, its note and its product', () {
    final alternative = ProductAlternative.fromJson(
      _alternative(1, 'Riz long grain', 'substitute'),
    );

    expect(alternative.isSubstitute, isTrue);
    expect(alternative.notes, 'Même usage, autre marque');
    expect(alternative.product.name, 'Riz long grain');
  });

  test('an alternative without a product is refused', () {
    expect(
      () => ProductAlternative.fromJson({'equivalence_id': 1}),
      throwsFormatException,
    );
  });

  testWidgets('the section lists the alternatives with their best price', (
    tester,
  ) async {
    final api = FakeApi(
      (request) => ok([
        _alternative(1, 'Riz long grain', 'substitute'),
        _alternative(2, 'Riz basmati', 'equivalent'),
      ]),
    );
    await _pump(tester, api);

    expect(find.text('Alternatives'), findsOneWidget);
    expect(find.text('Riz long grain'), findsOneWidget);
    expect(
      find.text('Produit de substitution · Même usage, autre marque'),
      findsOneWidget,
    );
    expect(find.text('Produit équivalent'), findsOneWidget);
    expect(find.text('700 FCFA'), findsNWidgets(2));
    expect(
      api.sent('GET', 'api/comparison/products/4/alternatives/'),
      hasLength(1),
    );
  });

  testWidgets('without alternative the section is absent', (tester) async {
    await _pump(tester, FakeApi((request) => ok(<Object?>[])));

    expect(find.text('Alternatives'), findsNothing);
  });

  testWidgets('an API error leaves the page without the section', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeApi((request) => (status: 500, body: {'detail': 'erreur'})),
    );

    expect(find.text('Alternatives'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
