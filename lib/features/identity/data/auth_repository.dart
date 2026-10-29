import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_providers.dart';
import 'auth_token_storage.dart';
import '../models/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(authTokenStorageProvider),
  );
});

class AuthRepository {
  const AuthRepository(this._client, this._tokenStorage);

  final Dio _client;
  final AuthTokenStorage _tokenStorage;

  Future<AuthUser?> restoreSession() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }
    try {
      final response = await _client.get<Map<String, dynamic>>('api/auth/me/');
      final data = response.data;
      if (data == null) {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      }
      return AuthUser.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _tokenStorage.clear();
        return null;
      }
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  Future<AuthUser> login({required String email, required String password}) =>
      _authenticate(
        path: 'api/auth/login/',
        data: {'email': email.trim(), 'password': password},
      );

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String passwordConfirm,
    required String displayName,
  }) => _authenticate(
    path: 'api/auth/signup/',
    data: {
      'email': email.trim(),
      'password': password,
      'password_confirm': passwordConfirm,
      'display_name': displayName.trim(),
      'country': 'GA',
    },
  );

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _client.post<void>(
          'api/auth/logout/',
          data: {'refresh': refreshToken},
        );
      }
    } on DioException {
      // Offline or token already revoked: the session ends on this device
      // anyway; the server-side token expires on its own.
    } finally {
      await _tokenStorage.clear();
    }
  }

  /// Forgets the tokens of this device without calling the API (they were
  /// revoked by the server, e.g. after a password change).
  Future<void> forgetSession() => _tokenStorage.clear();

  Future<AuthUser> _authenticate({
    required String path,
    required Map<String, Object> data,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      final result = response.data;
      final accessToken = result?['access'];
      final refreshToken = result?['refresh'];
      final userData = result?['user'];
      if (accessToken is! String ||
          accessToken.isEmpty ||
          refreshToken is! String ||
          refreshToken.isEmpty ||
          userData is! Map<String, dynamic>) {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      }
      final user = AuthUser.fromJson(userData);
      await _tokenStorage.writeTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      return user;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }
}
