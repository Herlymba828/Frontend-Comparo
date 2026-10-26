import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_providers.dart';
import 'package:frontend/features/identity/data/auth_token_storage.dart';

void main() {
  test(
    'refreshes expired access tokens and replays the original request',
    () async {
      final requests = <RequestOptions>[];
      final storage = _MemoryTokenStorage()
        ..accessToken = 'expired-access'
        ..refreshToken = 'current-refresh';
      final client = Dio(BaseOptions(baseUrl: 'https://api.example.test/'));
      client.httpClientAdapter = _JsonAdapter((options) {
        requests.add(options);
        if (options.path == 'api/auth/me/' &&
            options.headers['Authorization'] == 'Bearer expired-access') {
          return _JsonResponse(401, {
            'error': {'code': 'authentication_failed', 'detail': 'Expired'},
          });
        }
        if (options.path == 'api/auth/refresh/') {
          // Like the backend before its fix: an expired bearer on the refresh
          // route is rejected before the view runs.
          if (options.headers.containsKey('Authorization')) {
            return _JsonResponse(401, {
              'error': {'code': 'token_not_valid', 'detail': 'Expired'},
            });
          }
          expect(options.data, {'refresh': 'current-refresh'});
          return _JsonResponse(200, {
            'access': 'new-access',
            'refresh': 'rotated-refresh',
          });
        }
        return _JsonResponse(200, {'id': 41});
      });
      configureAuthenticatedApiClient(client, storage);

      final response = await client.get<Map<String, dynamic>>('api/auth/me/');

      expect(response.data, {'id': 41});
      expect(requests.map((request) => request.path), [
        'api/auth/me/',
        'api/auth/refresh/',
        'api/auth/me/',
      ]);
      expect(requests.last.headers['Authorization'], 'Bearer new-access');
      expect(storage.accessToken, 'new-access');
      expect(storage.refreshToken, 'rotated-refresh');
    },
  );

  Dio clientFor(
    _MemoryTokenStorage storage,
    _JsonResponse? Function(RequestOptions) respond, {
    void Function()? onSessionExpired,
  }) {
    final client = Dio(BaseOptions(baseUrl: 'https://api.example.test/'));
    client.httpClientAdapter = _JsonAdapter(respond);
    configureAuthenticatedApiClient(
      client,
      storage,
      onSessionExpired: onSessionExpired,
    );
    return client;
  }

  _JsonResponse expiredFor(RequestOptions options) => _JsonResponse(401, {
    'error': {'code': 'authentication_failed', 'detail': 'Expired'},
  });

  test('a network failure during refresh keeps the session', () async {
    var expired = 0;
    final storage = _MemoryTokenStorage()
      ..accessToken = 'expired-access'
      ..refreshToken = 'current-refresh';
    final client = clientFor(storage, (options) {
      if (options.path == 'api/auth/refresh/') {
        return null; // connection lost
      }
      return expiredFor(options);
    }, onSessionExpired: () => expired++);

    await expectLater(
      client.get<Object?>('api/auth/me/'),
      throwsA(isA<DioException>()),
    );
    expect(storage.refreshToken, 'current-refresh');
    expect(expired, 0);
  });

  test('a refused refresh token ends the session and notifies it', () async {
    var expired = 0;
    final storage = _MemoryTokenStorage()
      ..accessToken = 'expired-access'
      ..refreshToken = 'revoked-refresh';
    final client = clientFor(storage, (options) {
      if (options.path == 'api/auth/refresh/') {
        return _JsonResponse(401, {
          'error': {'code': 'token_not_valid', 'detail': 'Blacklisted'},
        });
      }
      return expiredFor(options);
    }, onSessionExpired: () => expired++);

    await expectLater(
      client.get<Object?>('api/auth/me/'),
      throwsA(isA<DioException>()),
    );
    expect(storage.refreshToken, isNull);
    expect(storage.accessToken, isNull);
    expect(expired, 1);
  });

  test('the bearer token is never sent to another origin', () async {
    final seen = <String, Object?>{};
    final storage = _MemoryTokenStorage()..accessToken = 'access';
    final client = clientFor(storage, (options) {
      seen[options.uri.host] = options.headers['Authorization'];
      return const _JsonResponse(200, {});
    });

    await client.get<Object?>('api/catalog/products/');
    await client.get<Object?>('https://tiers.example.org/pixel');

    expect(seen['api.example.test'], 'Bearer access');
    expect(seen['tiers.example.org'], isNull);
  });
}

class _JsonResponse {
  const _JsonResponse(this.statusCode, this.data);

  final int statusCode;
  final Object data;
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.respond);

  /// Returning null simulates a lost connection.
  final _JsonResponse? Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = respond(options);
    if (response == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'connection lost',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(response.data),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage implements AuthTokenStorage {
  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
}
