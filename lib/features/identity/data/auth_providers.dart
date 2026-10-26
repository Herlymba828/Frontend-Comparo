import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/data/catalog_providers.dart';
import '../models/auth_user.dart';
import 'auth_repository.dart';

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionController, AuthUser?>(
      AuthSessionController.new,
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

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AsyncData(null);
      // Searches and viewed products stay on the device otherwise.
      await ref.read(catalogRepositoryProvider).clearOfflineCache();
    }
  }
}
