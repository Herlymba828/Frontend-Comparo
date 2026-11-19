import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/acting_role.dart';
import 'package:frontend/core/network/api_providers.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/data/auth_token_storage.dart';
import 'package:frontend/features/identity/models/auth_user.dart';

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

class _Session extends AuthSessionController {
  _Session(this.roles);

  final List<String> roles;

  @override
  Future<AuthUser?> build() async => AuthUser(
    id: 1,
    email: 'moi@demo.ga',
    displayName: 'Moi',
    emailVerified: true,
    roles: roles,
  );
}

/// The real client provider, wired to a session and to the screen's path:
/// what the app does, not a hand-built client.
Future<(_Adapter, Dio)> _client(
  List<String> roles, {
  required String path,
}) async {
  final container = ProviderContainer(
    overrides: [
      authTokenStorageProvider.overrideWithValue(_Storage()),
      authSessionProvider.overrideWith(() => _Session(roles)),
      currentPathProvider.overrideWithValue(() => path),
    ],
  );
  addTearDown(container.dispose);
  // The session is loaded before the first screen asks for data.
  await container.read(authSessionProvider.future);
  final adapter = _Adapter();
  final client = container.read(apiClientProvider)..httpClientAdapter = adapter;
  return (adapter, client);
}

class _SlowSession extends AuthSessionController {
  _SlowSession(this.gate);

  final Completer<AuthUser?> gate;

  @override
  Future<AuthUser?> build() => gate.future;
}

class _FailedSession extends AuthSessionController {
  @override
  Future<AuthUser?> build() async => throw StateError('server down');
}

class _Visitor extends AuthSessionController {
  @override
  Future<AuthUser?> build() async => null;
}

/// A client whose session is [session], used before that session is ready.
(_Adapter, Dio) _earlyClient(AuthSessionController Function() session) {
  final container = ProviderContainer(
    overrides: [
      authTokenStorageProvider.overrideWithValue(_Storage()),
      authSessionProvider.overrideWith(session),
      currentPathProvider.overrideWithValue(() => '/'),
    ],
  );
  addTearDown(container.dispose);
  final adapter = _Adapter();
  final client = container.read(apiClientProvider)..httpClientAdapter = adapter;
  return (adapter, client);
}

void main() {
  group('before the session is known', () {
    test('a request still goes out while the session loads', () async {
      final gate = Completer<AuthUser?>();
      final (adapter, client) = _earlyClient(() => _SlowSession(gate));

      await client.get<Object?>('api/catalog/products/');

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers,
        isNot(contains(actingRoleHeader)),
      );
      gate.complete(null);
    });

    test('a request still goes out when the session failed to load', () async {
      final (adapter, client) = _earlyClient(_FailedSession.new);

      await client.get<Object?>('api/catalog/products/');

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers,
        isNot(contains(actingRoleHeader)),
      );
    });

    test('a visitor sends no space', () async {
      final (adapter, client) = _earlyClient(_Visitor.new);

      await client.get<Object?>('api/catalog/products/');

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers,
        isNot(contains(actingRoleHeader)),
      );
    });
  });

  test(
    'a request goes out with the role of the screen it comes from',
    () async {
      final (adapter, client) = await _client([
        'consumer',
        'courier',
      ], path: '/courier/deliveries');

      await client.get<Object?>('api/delivery/deliveries/');

      expect(adapter.requests.single.headers[actingRoleHeader], 'courier');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer access');
    },
  );

  test('the customer space acts as customer', () async {
    final (adapter, client) = await _client(['consumer', 'courier'], path: '/');

    await client.get<Object?>('api/catalog/products/');

    expect(adapter.requests.single.headers[actingRoleHeader], 'consumer');
  });

  test('the roles screen is reachable from the customer space', () async {
    final (adapter, client) = await _client([
      'consumer',
    ], path: '/account/roles');

    await client.get<Object?>('api/roles/mine/');

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.headers[actingRoleHeader], 'consumer');
  });
}
