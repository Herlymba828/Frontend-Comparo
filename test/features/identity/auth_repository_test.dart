import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/features/identity/data/auth_repository.dart';
import 'package:frontend/features/identity/data/auth_token_storage.dart';

void main() {
  test(
    'login stores JWT tokens and returns the authenticated profile',
    () async {
      late RequestOptions request;
      final client = _client((options) {
        request = options;
        return {
          'access': 'access.jwt.value',
          'refresh': 'refresh.jwt.value',
          'user': {
            'id': 41,
            'email': 'client@example.com',
            'display_name': 'Client',
            'email_verified': false,
          },
        };
      });
      final storage = _MemoryTokenStorage();

      final user = await AuthRepository(
        client,
        storage,
      ).login(email: ' client@example.com ', password: 'secret-password');

      expect(request.path, 'api/auth/login/');
      expect(request.data, {
        'email': 'client@example.com',
        'password': 'secret-password',
      });
      expect(storage.accessToken, 'access.jwt.value');
      expect(storage.refreshToken, 'refresh.jwt.value');
      expect(user.email, 'client@example.com');
      expect(user.displayName, 'Client');
    },
  );

  test('invalid authentication payload is rejected', () async {
    final repository = AuthRepository(
      _client((options) => {'access': 'access-only'}),
      _MemoryTokenStorage(),
    );

    await expectLater(
      repository.login(email: 'client@example.com', password: 'password'),
      throwsA(isA<ApiException>()),
    );
  });
}

Dio _client(Map<String, dynamic> Function(RequestOptions) respond) {
  final client = Dio(BaseOptions(baseUrl: 'https://api.example.test/'));
  client.httpClientAdapter = _JsonAdapter(respond);
  return client;
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.respond);

  final Map<String, dynamic> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
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
