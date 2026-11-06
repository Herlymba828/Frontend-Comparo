import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/app_navigation_bar.dart';

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(
      home: CustomerShell(location: '/cart', child: Text('contenu')),
    ),
  );
}

void main() {
  testWidgets('a phone gets the bottom bar', (tester) async {
    await _pump(tester, 390);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('a wide screen gets a side rail instead', (tester) async {
    await _pump(tester, 1366);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 2);
  });

  test('the tab follows the location, home only on its own path', () {
    expect(navIndexFor(customerTabs, '/'), 0);
    expect(navIndexFor(customerTabs, '/search'), 1);
    expect(navIndexFor(customerTabs, '/account'), 3);
  });
}
