import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/data/catalog_providers.dart';
import '../models/auth_user.dart';
import 'auth_repository.dart';

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionController, AuthUser?>(
      AuthSessionController.new,
    );

final activeAccountIdProvider = Provider<int?>(
  (ref) => ref.watch(authSessionProvider).value?.id,
);

class AuthSessionController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() =>
      ref.watch(authRepositoryProvider).restoreSession();

  Future<void> login({required String email, required String password}) async {
    final user = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    state = AsyncData(user);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String passwordConfirm,
    required String displayName,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .signUp(
          email: email,
          password: password,
          passwordConfirm: passwordConfirm,
          displayName: displayName,
        );
    state = AsyncData(user);
  }

  /// The server revoked every session (password changed): sign out here.
  Future<void> endRevokedSession() async {
    await ref.read(authRepositoryProvider).forgetSession();
    state = const AsyncData(null);
    await _clearDeviceData();
  }

  /// The server refused the tokens for good (the caller already dropped
  /// them): sign out here, and wipe what the account left on the device, as
  /// a sign-out does. Otherwise the next person on a shared phone would find
  /// the previous account's searches, positions, notes and photos.
  Future<void> endExpiredSession() async {
    state = const AsyncData(null);
    await _clearDeviceData();
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AsyncData(null);
      await _clearDeviceData();
    }
  }

  /// Searches and viewed products kept for offline reading would otherwise
  /// stay for the next person using the device. The app writes nothing else
  /// offline (no report is queued), so the cache is all there is to wipe.
  Future<void> _clearDeviceData() async {
    await ref.read(catalogRepositoryProvider).clearOfflineCache();
  }
}
