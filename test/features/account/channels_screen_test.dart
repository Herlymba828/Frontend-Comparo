import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/account/channels_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _page(List<Map<String, Object?>> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

Map<String, Object?> _channel(
  String channel,
  String label, {
  bool available = true,
  String? linkStatus,
  int linkId = 3,
}) => {
  'channel': channel,
  'label': label,
  'available': available,
  'link': linkStatus == null ? null : {'id': linkId, 'status': linkStatus},
};

Map<String, Object?> _preferences({
  String preferred = 'telegram',
  String fallback = '',
  String frequency = 'immediate',
  List<String> muted = const ['price_drop'],
}) => {
  'preferred_channel': preferred,
  'fallback_channel': fallback,
  'frequency': frequency,
  'muted_types': muted,
};

const _failure = (
  status: 500,
  body: {
    'error': {'code': 'server_error', 'detail': 'Panne.'},
  },
);

class _Backend {
  _Backend({
    List<Map<String, Object?>>? channels,
    Map<String, Object?>? preferences,
    this.deepLink = 'https://t.me/comparo_bot?start=ABC123',
    this.failWrites = false,
    this.failChannels = false,
  }) : channels =
           channels ??
           [
             _channel('telegram', 'Telegram', linkStatus: 'active'),
             _channel('whatsapp', 'WhatsApp'),
             _channel('sms', 'SMS', available: false),
           ],
       preferences = preferences ?? _preferences();

  final List<Map<String, Object?>> channels;
  final Map<String, Object?> preferences;
  final String deepLink;
  final bool failWrites;
  final bool failChannels;

  FakeReply answer(RequestOptions request) {
    final path = request.path;
    final isRead = request.method == 'GET';
    if (path == 'api/messaging/channels/') {
      return failChannels ? _failure : ok(_page(channels));
    }
    if (path == 'api/messaging/preferences/' && isRead) {
      return ok(preferences);
    }
    if (!isRead && failWrites) {
      return _failure;
    }
    if (path == 'api/messaging/links/') {
      return ok({'id': 9, 'code': 'ABC123', 'deep_link': deepLink});
    }
    if (path == 'api/messaging/preferences/') {
      return ok(preferences);
    }
    return ok(<String, Object?>{});
  }
}

Future<FakeApi> _open(
  WidgetTester tester,
  _Backend backend, {
  bool visitor = false,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeApi(backend.answer);
  await tester.pumpWidget(
    ProviderScope(
      // No automatic retry: a second attempt must come from the user.
      retry: (retryCount, error) => null,
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        authSessionProvider.overrideWith(
          visitor ? VisitorSession.new : SignedInSession.new,
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const ChannelsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// Records what the app puts on the clipboard.
List<String> _recordClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

Finder _picker(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('$label-'),
);

Future<void> _choose(WidgetTester tester, Finder picker, String option) async {
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Map<String, Object?> _lastPatch(FakeApi api) =>
    (api.sent('PATCH', 'api/messaging/preferences/').last.data as Map)
        .cast<String, Object?>();

void main() {
  group('the channel list', () {
    testWidgets('invites a visitor to sign in', (tester) async {
      await _open(tester, _Backend(), visitor: true);

      expect(
        find.text('Connectez-vous pour accéder à cet espace.'),
        findsOneWidget,
      );
    });

    testWidgets('tells linked, linkable and unavailable channels apart', (
      tester,
    ) async {
      await _open(tester, _Backend());

      expect(
        find.text(
          'Rien n’est envoyé sur un canal que vous n’avez pas lié. '
          'Écrivez STOP au bot pour tout arrêter.',
        ),
        findsOneWidget,
      );
      expect(find.text('Délier'), findsOneWidget);
      expect(find.text('Lier'), findsOneWidget);
      expect(find.text('Bientôt disponible'), findsOneWidget);
      expect(find.text('Alertes et bot de prix'), findsNWidgets(2));
    });

    testWidgets('an unknown channel still gets a row and an icon', (
      tester,
    ) async {
      await _open(tester, _Backend(channels: [_channel('signal', 'Signal')]));

      expect(find.text('Signal'), findsOneWidget);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final api = await _open(tester, _Backend());
      final before = api.sent('GET', 'api/messaging/channels/').length;

      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        api.sent('GET', 'api/messaging/channels/').length,
        greaterThan(before),
      );
    });

    testWidgets('shows an error with a way to retry', (tester) async {
      final api = await _open(tester, _Backend(failChannels: true));

      // The server's own message is shown, with a way to try again.
      expect(find.text('Panne.'), findsOneWidget);
      final before = api.sent('GET', 'api/messaging/channels/').length;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(
        api.sent('GET', 'api/messaging/channels/').length,
        greaterThan(before),
      );
    });
  });

  group('linking a bot channel', () {
    testWidgets('WhatsApp shows the message to send and its code', (
      tester,
    ) async {
      final api = await _open(tester, _Backend());

      await tester.tap(find.text('Lier'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/messaging/links/').single.data, {
        'channel': 'whatsapp',
        'phone': '',
      });
      expect(find.text('Lier WhatsApp'), findsOneWidget);
      expect(
        find.text('Envoyez ce message au bot depuis WhatsApp :'),
        findsOneWidget,
      );
      expect(find.text('LIER ABC123'), findsOneWidget);
      expect(find.text('Ce code expire dans 15 minutes.'), findsOneWidget);
      expect(find.text('Ouvrir WhatsApp'), findsOneWidget);
    });

    testWidgets('Telegram starts the bot instead', (tester) async {
      await _open(
        tester,
        _Backend(channels: [_channel('telegram', 'Telegram')]),
      );

      await tester.tap(find.text('Lier'));
      await tester.pumpAndSettle();

      expect(
        find.text('Démarrez le bot depuis Telegram, ou envoyez-lui :'),
        findsOneWidget,
      );
      expect(find.text('/start ABC123'), findsOneWidget);
    });

    testWidgets('the code can be copied, then the dialog closed', (
      tester,
    ) async {
      final copied = _recordClipboard(tester);
      await _open(tester, _Backend());
      await tester.tap(find.text('Lier'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copier le code'));
      await tester.pumpAndSettle();
      expect(copied, ['ABC123']);
      expect(find.text('Code copié.'), findsOneWidget);

      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('Lier WhatsApp'), findsNothing);
    });

    testWidgets('without a deep link there is no button to open the app', (
      tester,
    ) async {
      await _open(tester, _Backend(deepLink: ''));

      await tester.tap(find.text('Lier'));
      await tester.pumpAndSettle();

      expect(find.text('Lier WhatsApp'), findsOneWidget);
      expect(find.text('Ouvrir WhatsApp'), findsNothing);
    });

    testWidgets('a refused link shows an error and no dialog', (tester) async {
      await _open(tester, _Backend(failWrites: true));

      await tester.tap(find.text('Lier'));
      await tester.pumpAndSettle();

      expect(find.text('Lier WhatsApp'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('linking an SMS number', () {
    _Backend sms() => _Backend(channels: [_channel('sms', 'SMS')]);

    testWidgets('sends the number, then confirms the code received', (
      tester,
    ) async {
      final api = await _open(tester, sms());

      await tester.tap(find.text('Lier'));
      await tester.pumpAndSettle();
      expect(find.text('Lier mon numéro'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '+24106123456');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(find.text('Code reçu par SMS'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/messaging/links/').single.data, {
        'channel': 'sms',
        'phone': '+24106123456',
      });
      expect(api.sent('POST', 'api/messaging/links/9/confirm/').single.data, {
        'code': '123456',
      });
    });

    testWidgets('a cancelled number sends nothing', (tester) async {
      final api = await _open(tester, sms());

      await tester.tap(find.text('Lier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/messaging/links/'), isEmpty);
    });

    testWidgets('a cancelled code leaves the link unconfirmed', (tester) async {
      final api = await _open(tester, sms());

      await tester.tap(find.text('Lier'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '+24106123456');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/messaging/links/'), hasLength(1));
      expect(api.sent('POST', 'api/messaging/links/9/confirm/'), isEmpty);
    });
  });

  group('unlinking', () {
    testWidgets('asks first, then removes the link', (tester) async {
      final api = await _open(tester, _Backend());

      await tester.tap(find.text('Délier'));
      await tester.pumpAndSettle();
      expect(find.text('Délier Telegram ?'), findsOneWidget);
      await tester.tap(find.text('Délier').last);
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/messaging/links/3/'), hasLength(1));
    });

    testWidgets('does nothing when the user goes back', (tester) async {
      final api = await _open(tester, _Backend());

      await tester.tap(find.text('Délier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/messaging/links/3/'), isEmpty);
    });
  });

  group('the preferences', () {
    _Backend twoLinked({
      Map<String, Object?>? preferences,
      bool failWrites = false,
    }) => _Backend(
      channels: [
        _channel('telegram', 'Telegram', linkStatus: 'active'),
        _channel('sms', 'SMS', linkStatus: 'active', linkId: 4),
      ],
      preferences: preferences,
      failWrites: failWrites,
    );

    testWidgets('show what is switched on and off', (tester) async {
      await _open(tester, _Backend());

      expect(find.text('Mes préférences'), findsOneWidget);
      final muted = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Baisses de prix'),
      );
      final alerts = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Alertes de prix'),
      );
      expect(muted.value, isFalse);
      expect(alerts.value, isTrue);
    });

    testWidgets('muting an alert type keeps the ones already muted', (
      tester,
    ) async {
      final api = await _open(tester, _Backend());

      await tester.tap(find.widgetWithText(SwitchListTile, 'Alertes de prix'));
      await tester.pumpAndSettle();

      expect(_lastPatch(api)['muted_types'], ['price_drop', 'price_alert']);
    });

    testWidgets('switching a muted type back on removes only that one', (
      tester,
    ) async {
      final api = await _open(tester, _Backend());

      await tester.tap(find.widgetWithText(SwitchListTile, 'Baisses de prix'));
      await tester.pumpAndSettle();

      expect(_lastPatch(api)['muted_types'], isEmpty);
    });

    testWidgets('the frequency can be changed', (tester) async {
      final api = await _open(tester, _Backend());

      await _choose(
        tester,
        find.text('Dès que possible'),
        'Alertes de prix regroupées à 8 h',
      );

      expect(_lastPatch(api)['frequency'], 'daily');
    });

    testWidgets('a fallback channel can be chosen beside the preferred one', (
      tester,
    ) async {
      final api = await _open(tester, twoLinked());

      await _choose(tester, _picker('Canal de secours'), 'SMS');

      expect(_lastPatch(api)['fallback_channel'], 'sms');
    });

    testWidgets('changing the preferred channel drops a clashing fallback', (
      tester,
    ) async {
      final api = await _open(
        tester,
        twoLinked(preferences: _preferences(fallback: 'sms')),
      );

      await _choose(tester, _picker('Canal préféré'), 'SMS');

      final patch = _lastPatch(api);
      expect(patch['preferred_channel'], 'sms');
      expect(patch['fallback_channel'], '');
    });

    testWidgets('choosing the app alone clears both channels', (tester) async {
      final api = await _open(
        tester,
        twoLinked(preferences: _preferences(fallback: 'sms')),
      );

      await _choose(tester, _picker('Canal préféré'), 'Application seulement');

      final patch = _lastPatch(api);
      expect(patch['preferred_channel'], '');
      expect(patch['fallback_channel'], '');
    });

    testWidgets('a fallback needs a preferred channel first', (tester) async {
      final api = await _open(
        tester,
        twoLinked(preferences: _preferences(preferred: '')),
      );

      await tester.tap(_picker('Canal de secours'));
      await tester.pumpAndSettle();

      expect(api.sent('PATCH', 'api/messaging/preferences/'), isEmpty);
      expect(find.text('Telegram'), findsOneWidget);
    });

    testWidgets('a refused change shows the error', (tester) async {
      final api = await _open(tester, twoLinked(failWrites: true));

      await tester.tap(find.widgetWithText(SwitchListTile, 'Retours en stock'));
      await tester.pumpAndSettle();

      expect(api.sent('PATCH', 'api/messaging/preferences/'), hasLength(1));
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('a channel unlinked since is shown as none', (tester) async {
      await _open(
        tester,
        _Backend(
          channels: [_channel('telegram', 'Telegram')],
          preferences: _preferences(preferred: 'telegram'),
        ),
      );

      expect(find.text('Application seulement'), findsOneWidget);
    });
  });
}
