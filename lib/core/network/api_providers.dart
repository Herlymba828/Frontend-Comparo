import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/identity/data/auth_providers.dart';
import '../../features/identity/data/auth_token_storage.dart';
import '../config/app_config.dart';
import 'api_client.dart';

final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  return SecureAuthTokenStorage();
});

final apiClientProvider = Provider<Dio>((ref) {
  final client = createApiClient(AppConfig.current);
  final tokenStorage = ref.watch(authTokenStorageProvider);
  configureAuthenticatedApiClient(
    client,
    tokenStorage,
    // Tokens were rejected by the server: reflect the logout in the UI.
    onSessionExpired: () => ref.invalidate(authSessionProvider),
  );
  ref.onDispose(client.close);
  return client;
});

/// Routes d'authentification : elles ne doivent jamais recevoir le jeton
/// d'accès (souvent expiré au moment du rafraîchissement).
bool _isAuthPath(String path) =>
    path.endsWith('api/auth/login/') ||
    path.endsWith('api/auth/signup/') ||
    path.endsWith('api/auth/refresh/');

void configureAuthenticatedApiClient(
  Dio client,
  AuthTokenStorage tokenStorage, {
  void Function()? onSessionExpired,
}) {
  Future<String?>? refreshInProgress;

  Future<String?> refreshAccessToken() {
    final currentRefresh = refreshInProgress;
    if (currentRefresh != null) {
      return currentRefresh;
    }
    final refresh = _refreshAccessToken(
      client,
      tokenStorage,
      onSessionExpired: onSessionExpired,
    );
    refreshInProgress = refresh;
    return refresh.whenComplete(() {
      refreshInProgress = null;
    });
  }

  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Bearer token only for the API's own origin, never for auth routes.
        final apiOrigin = Uri.parse(client.options.baseUrl).origin;
        if (!_isAuthPath(options.path) && options.uri.origin == apiOrigin) {
          final accessToken = await tokenStorage.readAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        final isAuthRequest = _isAuthPath(request.path);
        if (error.response?.statusCode != 401 ||
            request.extra['authRetry'] == true ||
            isAuthRequest) {
          handler.next(error);
          return;
        }

        final accessToken = await refreshAccessToken();
        if (accessToken == null) {
          handler.next(error);
          return;
        }
        request
          ..headers['Authorization'] = 'Bearer $accessToken'
          ..extra['authRetry'] = true;
        if (request.path.endsWith('api/auth/logout/') && request.data is Map) {
          final refreshToken = await tokenStorage.readRefreshToken();
          if (refreshToken != null) {
            request.data = Map<String, dynamic>.from(request.data as Map)
              ..['refresh'] = refreshToken;
          }
        }
        try {
          handler.resolve(await client.fetch<dynamic>(request));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    ),
  );
}

Future<String?> _refreshAccessToken(
  Dio client,
  AuthTokenStorage tokenStorage, {
  void Function()? onSessionExpired,
}) async {
  Future<String?> expire() async {
    await tokenStorage.clear();
    onSessionExpired?.call();
    return null;
  }

  final refreshToken = await tokenStorage.readRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) {
    return expire();
  }

  try {
    final response = await client.post<Map<String, dynamic>>(
      'api/auth/refresh/',
      data: {'refresh': refreshToken},
    );
    final access = response.data?['access'];
    final rotatedRefresh = response.data?['refresh'];
    if (access is! String || access.isEmpty) {
      return await expire();
    }
    await tokenStorage.writeTokens(
      accessToken: access,
      refreshToken: rotatedRefresh is String && rotatedRefresh.isNotEmpty
          ? rotatedRefresh
          : refreshToken,
    );
    return access;
  } on DioException catch (error) {
    // Only a refusal of the refresh token ends the session. A timeout, a lost
    // connection or a 5xx keeps the tokens so the user stays signed in and
    // the next request can try again.
    final status = error.response?.statusCode;
    if (status == 400 || status == 401 || status == 403) {
      // Another tab/isolate may have rotated the tokens meanwhile: only expire
      // if the refresh token we sent is still the stored one.
      if (await tokenStorage.readRefreshToken() == refreshToken) {
        return await expire();
      }
      return await tokenStorage.readAccessToken();
    }
    return null;
  } on TypeError {
    return await expire();
  }
}
