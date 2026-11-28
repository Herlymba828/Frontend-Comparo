import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_providers.dart';
import 'package:frontend/features/catalog/data/catalog_providers.dart';
import 'package:frontend/features/catalog/data/catalog_repository.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/data/auth_repository.dart';
import 'package:frontend/features/identity/data/auth_token_storage.dart';
import 'package:frontend/features/identity/models/auth_user.dart';

import '../../support/fake_api.dart';

/// What the device keeps of an account: tokens, searches and viewed products.
/// A refused session must wipe all of it, like a sign-out: the next person on
/// a shared phone must find none of it.
class _Device {
  int tokenWipes = 0;
  int cacheWipes = 0;
}

class _Tokens implements AuthTokenStorage {
  _Tokens(this.device);

  final _Device device;

  @override
  Future<String?> readAccessToken() async => 'old-access';

  @override
  Future<String?> readRefreshToken() async => 'old-refresh';

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async => device.tokenWipes++;
}

class _Auth extends AuthRepository {
  _Auth(_Device device) : super(Dio(), _Tokens(device));

  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(
    id: 1,
    email: 'client@demo.ga',
    displayName: 'Client',
    emailVerified: true,
  );

  @override
  Future<void> forgetSession() async {}
}

class _Catalog extends CatalogRepository {
  _Catalog(this.device) : super(Dio());

  final _Device device;

  @override
  Future<void> clearOfflineCache() async => device.cacheWipes++;
}

ProviderContainer _container(_Device device) {
  final container = ProviderContainer(
    // No automatic retry: a failing provider must fail once.
    retry: (retryCount, error) => null,
    overrides: [
      authTokenStorageProvider.overrideWithValue(_Tokens(device)),
      authRepositoryProvider.overrideWithValue(_Auth(device)),
      catalogRepositoryProvider.overrideWithValue(_Catalog(device)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('an expired session is ended and the device data is wiped', () async {
    final device = _Device();
    final container = _container(device);
    await container.read(authSessionProvider.future);

    await container.read(authSessionProvider.notifier).endExpiredSession();

    expect(container.read(authSessionProvider).value, isNull);
    expect(device.cacheWipes, 1);
  });

  test('a refused refresh token wipes the offline cache', () async {
    final device = _Device();
    final container = _container(device);
    await container.read(authSessionProvider.future);
    // Every call, the renewal included, is answered 401.
    final api = FakeApi((request) => (status: 401, body: <String, Object?>{}));
    container.read(apiClientProvider).httpClientAdapter = api;

    await expectLater(
      container.read(apiClientProvider).get<dynamic>('api/catalog/products/'),
      throwsA(isA<DioException>()),
    );
    // The wipe runs after the failing request has been answered.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(device.tokenWipes, greaterThanOrEqualTo(1));
    expect(container.read(authSessionProvider).value, isNull);
    expect(device.cacheWipes, 1);
  });

  test('a signed-out device is not wiped twice by a late failure', () async {
    final device = _Device();
    final container = _container(device);
    await container.read(authSessionProvider.future);

    await container.read(authSessionProvider.notifier).logout();

    expect(device.cacheWipes, 1);
  });
}
