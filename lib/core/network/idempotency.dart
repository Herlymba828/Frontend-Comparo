import 'dart:math';

/// A random key for the Idempotency-Key header (128 bits, hexadecimal).
String newIdempotencyKey() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// One Idempotency-Key per user action, kept until the action succeeds.
///
/// The server requires a key on checkout, payment and refund. Retrying the
/// same action (same content) after a lost answer sends the same key, so the
/// server replays the first result instead of acting twice. A different
/// content (another payment method, accepted new prices) is another action,
/// with its own key: the server refuses a key reused for a different body.
class ActionKeys {
  final Map<Object, String> _keys = {};

  /// The key of [action]; records compare by value: `(orderId, method)`.
  String keyFor(Object action) => _keys.putIfAbsent(action, newIdempotencyKey);

  /// The action is done: doing it again later is a new action.
  void succeeded(Object action) => _keys.remove(action);
}
