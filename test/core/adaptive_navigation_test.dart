import 'package:comparo_ui/comparo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_navigation_bar.dart';

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // The bar reads its colours from the app theme (the design system's
  // extension), and the shell its list count from the state container.
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: const CustomerShell(location: '/cart', child: Text('contenu')),
      ),
    ),
  );
}

void main() {
  testWidgets('a phone gets the bottom bar', (tester) async {
    await _pump(tester, 390);
    expect(find.byType(ComparoNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('a wide screen gets a side rail instead', (tester) async {
    await _pump(tester, 1366);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(ComparoNavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 2);
  });

  testWidgets('the third tab is "Ma liste", as in the design', (tester) async {
    await _pump(tester, 390);
    expect(find.text('Ma liste'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  test('the tab follows the location, home only on its own path', () {
    expect(navIndexFor(customerTabs, '/'), 0);
    expect(navIndexFor(customerTabs, '/search'), 1);
    expect(navIndexFor(customerTabs, '/account'), 3);
  });
}
