import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/acting_role.dart';
import 'package:frontend/core/network/api_providers.dart';
import 'package:frontend/features/identity/data/auth_token_storage.dart';

class _Storage implements AuthTokenStorage {
  @override
  Future<String?> readAccessToken() async => 'access';

  @override
  Future<String?> readRefreshToken() async => 'refresh';

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('actingRoleFor', () {
    const courierAndCustomer = ['consumer', 'courier'];

    test('the customer space acts as customer', () {
      expect(actingRoleFor(path: '/', roles: courierAndCustomer), 'consumer');
      expect(
        actingRoleFor(path: '/orders/12', roles: courierAndCustomer),
        'consumer',
      );
    });

    test('a role space acts as that role', () {
      expect(
        actingRoleFor(path: '/courier/deliveries', roles: courierAndCustomer),
        'courier',
      );
      expect(
        actingRoleFor(
          path: '/merchant/orders/4',
          roles: const ['consumer', 'merchant'],
        ),
        'merchant',
      );
    });

    test('the space is matched as a path, not as a prefix of a word', () {
      expect(
        actingRoleFor(
          path: '/merchants-guide',
          roles: const ['consumer', 'merchant'],
        ),
        'consumer',
      );
    });

    test('a customer opening the merchant space acts as customer', () {
      // Opening a shop is how the merchant role is earned.
      expect(
        actingRoleFor(path: '/merchant/orders', roles: const ['consumer']),
        'consumer',
      );
    });

    test('admins moderate and handle support as admin', () {
      const admin = ['consumer', 'admin'];
      expect(actingRoleFor(path: '/moderation/pending', roles: admin), 'admin');
      expect(actingRoleFor(path: '/agent/complaints', roles: admin), 'admin');
    });

    test('a moderator who is also an admin moderates as moderator', () {
      expect(
        actingRoleFor(
          path: '/moderation/roles',
          roles: const ['consumer', 'admin', 'moderator'],
        ),
        'moderator',
      );
    });

    test('nothing is asked without roles', () {
      expect(actingRoleFor(path: '/', roles: const []), isNull);
    });

    test(
      'without the customer role no restriction is asked outside a space',
      () {
        expect(actingRoleFor(path: '/', roles: const ['courier']), isNull);
      },
    );
  });

  group('the header on requests', () {
    Future<_Adapter> send(String path, {String? Function()? actingRole}) async {
      final adapter = _Adapter();
      final client = Dio(BaseOptions(baseUrl: 'https://api.example.test/'))
        ..httpClientAdapter = adapter;
      configureAuthenticatedApiClient(
        client,
        _Storage(),
        actingRole: actingRole,
      );
      await client.get<Object?>(path);
      return adapter;
    }

    test('is sent with the role of the current space', () async {
      final adapter = await send('api/orders/', actingRole: () => 'courier');
      expect(adapter.requests.single.headers[actingRoleHeader], 'courier');
    });

    test('is not sent when there is no role to act as', () async {
      final adapter = await send('api/orders/', actingRole: () => null);
      expect(
        adapter.requests.single.headers,
        isNot(contains(actingRoleHeader)),
      );
    });

    test('is not sent without the feature (older callers)', () async {
      final adapter = await send('api/orders/');
      expect(
        adapter.requests.single.headers,
        isNot(contains(actingRoleHeader)),
      );
    });

    test('never stops a request, even when it cannot be worked out', () async {
      final adapter = await send(
        'api/orders/',
        actingRole: () => throw StateError('router not ready'),
      );
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers,
        isNot(contains(actingRoleHeader)),
      );
      // The rest of the request is unchanged.
      expect(adapter.requests.single.headers['Authorization'], 'Bearer access');
    });

    test('is never sent to the session routes', () async {
      var asked = 0;
      final adapter = await send(
        'api/auth/me/',
        actingRole: () {
          asked++;
          return 'consumer';
        },
      );
      expect(
        adapter.requests.single.headers,
        isNot(contains(actingRoleHeader)),
      );
      // The session is not asked for its roles while it loads.
      expect(asked, 0);
    });

    test('is never sent to another origin', () async {
      final adapter = _Adapter();
      final client = Dio(BaseOptions(baseUrl: 'https://api.example.test/'))
        ..httpClientAdapter = adapter;
      configureAuthenticatedApiClient(
        client,
        _Storage(),
        actingRole: () => 'merchant',
      );
      await client.get<Object?>('https://elsewhere.example/file.png');
      final headers = adapter.requests.single.headers;
      expect(headers, isNot(contains(actingRoleHeader)));
      expect(headers, isNot(contains('Authorization')));
    });
  });
}
