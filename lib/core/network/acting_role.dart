import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The name of the header that tells the server which space a request is
/// made from. The server then treats the user as holding that role only:
/// separation of responsibilities is enforced there, not only by the screens.
const actingRoleHeader = 'X-Acting-Role';

/// The path of the screen the user is on (`/merchant/orders`), read at the
/// time of each request. The app overrides it with the router; the default
/// (no location) sends no space.
final currentPathProvider = Provider<String Function()>(
  (ref) =>
      () => '/',
);

// The roles that open each space, most specific first: admins moderate and
// handle support as well (same rule as the server).
const _spaceRoles = <String, List<String>>{
  '/merchant': ['merchant'],
  '/courier': ['courier'],
  '/moderation': ['moderator', 'admin'],
  '/agent': ['support', 'admin'],
};

bool _isIn(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// The role to act as on [path] for an account holding [roles], or null when
/// no restriction should be asked (not signed in, or no usable role).
///
/// A screen of a space the account cannot enter (a customer opening a shop,
/// which grants the merchant role) acts as customer: the server refuses a
/// role the account does not hold.
String? actingRoleFor({required String path, required Iterable<String> roles}) {
  final held = roles.toSet();
  if (held.isEmpty) {
    return null;
  }
  for (final entry in _spaceRoles.entries) {
    if (!_isIn(path, entry.key)) {
      continue;
    }
    for (final role in entry.value) {
      if (held.contains(role)) {
        return role;
      }
    }
  }
  return held.contains('consumer') ? 'consumer' : null;
}
