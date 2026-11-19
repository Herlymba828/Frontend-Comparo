import 'dart:developer' as developer;

/// Where an uncaught error goes. The default writes to the device log; a
/// remote reporter (crash service, own endpoint) replaces it in `bootstrap`
/// without touching the handlers.
abstract interface class ErrorReporter {
  /// [source] says who caught it: `flutter` (build, layout, gestures) or
  /// `platform` (an async error nobody awaited).
  void report(Object error, StackTrace? stack, {required String source});
}

/// Sends each error to several reporters (the device log and a remote one).
/// A reporter that fails does not stop the others.
class CompositeErrorReporter implements ErrorReporter {
  const CompositeErrorReporter(this.reporters);

  final List<ErrorReporter> reporters;

  @override
  void report(Object error, StackTrace? stack, {required String source}) {
    for (final reporter in reporters) {
      try {
        reporter.report(error, stack, source: source);
      } on Object catch (failure) {
        developer.log(
          '${reporter.runtimeType} failed: ${failure.runtimeType}',
          name: 'comparo',
          level: 1000,
        );
      }
    }
  }
}

/// A message goes to the log at most this long: an error text can embed a
/// whole response.
const maxReportedMessageLength = 500;

final _secretPatterns = <RegExp>[
  // "Authorization: Bearer abc.def", "Bearer abc.def"
  RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
  // "token=...", "access=...", "refresh=...", "password=...", "code=..."
  RegExp(
    r'\b(token|access|refresh|password|secret|code|key)=[^&\s"]+',
    caseSensitive: false,
  ),
];

/// [text] without anything that authenticates (tokens, passwords, codes).
String redactSecrets(String text) {
  var clean = text;
  for (final pattern in _secretPatterns) {
    clean = clean.replaceAllMapped(pattern, (match) {
      final value = match.group(0)!;
      final separator = value.indexOf('=');
      return separator > 0
          ? '${value.substring(0, separator + 1)}[redacted]'
          : 'Bearer [redacted]';
    });
  }
  return clean;
}

/// Writes errors to the device log (`adb logcat -s comparo`), without secrets
/// and without the user's data: type, short message and stack only.
class LogErrorReporter implements ErrorReporter {
  const LogErrorReporter({this.sink = _developerLog});

  /// Receives each formatted entry; replaced in tests.
  final void Function(String entry) sink;

  static void _developerLog(String entry) =>
      developer.log(entry, name: 'comparo', level: 1000);

  @override
  void report(Object error, StackTrace? stack, {required String source}) {
    var message = redactSecrets(error.toString());
    if (message.length > maxReportedMessageLength) {
      message = '${message.substring(0, maxReportedMessageLength)}…';
    }
    final trace = stack == null ? '' : '\n${redactSecrets(stack.toString())}';
    sink('[$source] ${error.runtimeType}: $message$trace');
  }
}
