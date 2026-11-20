import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/account/consents_repository.dart';
import 'package:frontend/features/account/consents_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';

import '../support/fake_api.dart';

Map<String, Object?> _row(
  String purpose,
  String label, {
  bool granted = false,
}) => {
  'purpose': purpose,
  'label': label,
  'granted': granted,
  'granted_at': null,
  'revoked_at': null,
};

FakeReply _handler(RequestOptions request, Map<String, bool> state) {
  if (request.method == 'PATCH') {
    final purpose = request.path.split('/').reversed.elementAt(1);
    state[purpose] = (request.data as Map)['granted'] as bool;
    return ok(_row(purpose, 'x', granted: state[purpose]!));
  }
  return ok({
    'results': [
      _row('location', 'Localisation', granted: state['location'] ?? false),
      _row('analytics', 'Statistiques', granted: state['analytics'] ?? false),
    ],
  });
}

void main() {
  test('a consent reads its purpose, label and answer', () {
    final consent = Consent.fromJson(_row('location', 'Localisation'));
    expect(consent.purpose, 'location');
    expect(consent.granted, isFalse);
  });

  testWidgets('every purpose is shown, refused until the person says yes', (
    tester,
  ) async {
    final state = <String, bool>{};
    final api = FakeApi((request) => _handler(request, state));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonApiProvider.overrideWithValue(api.jsonApi),
          authSessionProvider.overrideWith(SignedInSession.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ConsentsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Localisation'), findsOneWidget);
    expect(find.text('Statistiques'), findsOneWidget);
    expect(
      tester.widgetList<Switch>(find.byType(Switch)).every((s) => !s.value),
      isTrue,
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final sent = api.sent('PATCH', 'api/auth/consents/location/');
    expect(sent, hasLength(1));
    expect((sent.single.data as Map)['granted'], isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
  });
}
