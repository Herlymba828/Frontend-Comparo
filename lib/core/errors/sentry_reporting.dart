import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'error_reporter.dart';

/// Crash reporting settings, fixed at build time with `--dart-define`:
///
///     --dart-define=SENTRY_DSN=https://<key>@<host>/<project>
///     --dart-define=SENTRY_ENVIRONMENT=production
///     --dart-define=APP_RELEASE=comparo@1.0.0+1
///
/// The DSN is a public key: it lets the app send events to the project, not
/// read them. Without it nothing is sent and the app only logs on the device.
class SentrySettings {
  const SentrySettings({
    required this.dsn,
    this.environment = 'production',
    this.release = '',
  });

  static const fromEnvironment = SentrySettings(
    dsn: String.fromEnvironment('SENTRY_DSN'),
    environment: String.fromEnvironment(
      'SENTRY_ENVIRONMENT',
      defaultValue: 'production',
    ),
    release: String.fromEnvironment('APP_RELEASE'),
  );

  final String dsn;
  final String environment;
  final String release;

  bool get isEnabled => dsn.trim().isNotEmpty;
}

/// Applies [settings] with the privacy rules of the product: what leaves the
/// phone is the error, its stack and the app version. Never the user, the
/// requests, a screenshot, the screens visited nor the device's name
/// (minimisation: BR-101).
void configureSentryOptions(
  SentryFlutterOptions options,
  SentrySettings settings,
) {
  options
    ..dsn = settings.dsn.trim()
    ..environment = settings.environment
    ..release = settings.release.isEmpty ? null : settings.release
    ..sendDefaultPii = false
    ..attachScreenshot = false
    ..attachViewHierarchy = false
    ..attachThreads = false
    ..captureFailedRequests = false
    ..reportPackages = false
    // No performance monitoring, sessions or automatic breadcrumbs: errors
    // only.
    ..tracesSampleRate = 0
    ..enableAutoPerformanceTracing = false
    ..enableUserInteractionTracing = false
    ..enableUserInteractionBreadcrumbs = false
    ..enableAutoNativeBreadcrumbs = false
    ..enableAutoSessionTracking = false
    // A breadcrumb can carry a route with an order number or a query.
    ..beforeBreadcrumb = ((breadcrumb, hint) => null)
    ..beforeSend = scrubSentryEvent;
}

/// [event] without what identifies a person or authenticates, and with the
/// secrets removed from the texts that remain.
SentryEvent scrubSentryEvent(SentryEvent event, Hint hint) {
  event
    ..user = null
    ..request = null
    // Deprecated in favour of contexts, but still sent when something sets it.
    // ignore: deprecated_member_use
    ..extra = null
    ..breadcrumbs = null
    ..serverName = null;
  final message = event.message;
  if (message != null) {
    event.message = SentryMessage(redactSecrets(message.formatted));
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    final value = exception.value;
    if (value != null) {
      exception.value = redactSecrets(value);
    }
  }
  return event;
}

/// Sends the errors caught by the global handlers to Sentry.
class SentryErrorReporter implements ErrorReporter {
  const SentryErrorReporter();

  @override
  void report(Object error, StackTrace? stack, {required String source}) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: (scope) => scope.setTag('source', source),
      ),
    );
  }
}
