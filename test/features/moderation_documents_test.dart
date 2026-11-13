import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/features/moderation/moderation_review_screens.dart';

/// Answers the moderation routes with canned JSON and records the calls.
class _FakeApi implements HttpClientAdapter {
  _FakeApi(this.documentsByShop);

  final Map<int, List<Map<String, Object>>> documentsByShop;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    final path = options.path;
    Object body = const <String, Object>{};
    if (path == 'api/merchants/to_verify/') {
      body = [
        for (final id in documentsByShop.keys)
          {'id': id, 'name': 'Boutique $id', 'created_at': null},
      ];
    }
    final match = RegExp(r'api/merchants/(\d+)/documents/').firstMatch(path);
    if (match != null) {
      body = documentsByShop[int.parse(match.group(1)!)] ?? const [];
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_FakeApi> _pump(
  WidgetTester tester,
  Map<int, List<Map<String, Object>>> documentsByShop,
) async {
  final fake = _FakeApi(documentsByShop);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/'))
    ..httpClientAdapter = fake;
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [jsonApiProvider.overrideWithValue(JsonApi(dio))],
      child: const MaterialApp(home: Scaffold(body: ModerationShopsScreen())),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('a moderator sees the documents a shop sent', (tester) async {
    await _pump(tester, {
      7: [
        {
          'id': 1,
          'kind': 'registration',
          'kind_label': 'Registre du commerce (RCCM)',
          'download_url': '/api/merchants/7/documents/1/file/',
          'created_at': '2026-11-10T09:00:00Z',
        },
      ],
    });

    expect(find.text('Boutique 7'), findsOneWidget);
    expect(find.text('Registre du commerce (RCCM)'), findsOneWidget);
  });

  testWidgets('verifying a shop without documents asks first', (tester) async {
    final api = await _pump(tester, {8: const []});

    expect(find.text('Aucun justificatif envoyé.'), findsOneWidget);
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    expect(find.text('Vérifier sans justificatif ?'), findsOneWidget);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(api.calls.where((call) => call.contains('/verify/')), isEmpty);
  });
}
