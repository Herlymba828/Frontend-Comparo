import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/core/theme/app_theme.dart';

Future<void> _open(WidgetTester tester, String location) async {
  // Before the first build, so the home screen (and its network calls) is
  // never mounted.
  AppRouter.router.go(location);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
      ),
    ),
  );
  await tester.pump();
  // Lets the home screen's first requests (zero-delay timers) finish.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('an unknown route shows a French not-found page', (tester) async {
    await _open(tester, '/cette-page-n-existe-pas');

    expect(find.text('Page introuvable'), findsOneWidget);
    expect(find.text('Retour à l’accueil'), findsOneWidget);
  });

  testWidgets('an invalid id in the address is not read as 0', (tester) async {
    for (final location in [
      '/product/abc',
      '/orders/0',
      '/orders/-4',
      '/courier/deliveries/x1',
      '/moderation/applications/%20',
    ]) {
      await _open(tester, location);
      expect(find.text('Page introuvable'), findsOneWidget, reason: location);
    }
  });
}
