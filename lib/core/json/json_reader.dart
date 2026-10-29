/// Defensive readers for API payloads: a missing or mistyped field becomes a
/// neutral value instead of crashing the screen, except where a value is
/// required (`requireInt`, `requireString`), which throws a FormatException.
extension JsonReader on Map<String, dynamic> {
  int requireInt(String key) {
    final value = this[key];
    if (value is int) {
      return value;
    }
    throw FormatException('Missing integer "$key".');
  }

  String requireString(String key) {
    final value = this[key];
    if (value is String) {
      return value;
    }
    throw FormatException('Missing string "$key".');
  }

  int? intOrNull(String key) {
    final value = this[key];
    return value is int ? value : null;
  }

  String string(String key, [String fallback = '']) {
    final value = this[key];
    if (value is String) {
      return value;
    }
    if (value is num) {
      return value.toString();
    }
    return fallback;
  }

  String? stringOrNull(String key) {
    final value = this[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  bool flag(String key, [bool fallback = false]) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  DateTime? dateOrNull(String key) {
    final value = this[key];
    return value is String ? DateTime.tryParse(value)?.toLocal() : null;
  }

  Map<String, dynamic>? mapOrNull(String key) {
    final value = this[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  List<Map<String, dynamic>> maps(String key) {
    final value = this[key];
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  List<String> strings(String key) {
    final value = this[key];
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item is String) item,
    ];
  }
}
