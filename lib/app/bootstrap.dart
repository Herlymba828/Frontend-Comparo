import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../core/errors/error_reporter.dart';
import '../core/errors/global_error_handlers.dart';
import '../core/errors/sentry_reporting.dart';
import '../core/network/acting_role.dart';
import 'app.dart';
import 'router.dart';

// MVP: offline, the app only shows cached data. Nothing is sent by itself at
// start-up or when the network comes back (no write synchronisation).
//
// Crash reporting is off until the build sets SENTRY_DSN: then the errors of
// the global handlers also go to Sentry (see sentry_reporting.dart).
Future<void> bootstrap({
  SentrySettings settings = SentrySettings.fromEnvironment,
}) async {
  if (!settings.isEnabled) {
    _start(const LogErrorReporter());
    return;
  }
  await SentryFlutter.init(
    (options) => configureSentryOptions(options, settings),
    // Sentry installs its own handlers first; ours then replace them so that
    // every error takes one path (log, then Sentry) and is reported once.
    appRunner: () => _start(
      const CompositeErrorReporter([LogErrorReporter(), SentryErrorReporter()]),
    ),
  );
}

void _start(ErrorReporter reporter) {
  // Before anything runs: an error during start-up is reported too.
  installGlobalErrorHandlers(reporter);
  runApp(
    ProviderScope(
      overrides: [
        // Each request tells the server which space it comes from (the
        // screen's path): the server limits the user to that role.
        currentPathProvider.overrideWithValue(
          () => AppRouter.router.routeInformationProvider.value.uri.path,
        ),
      ],
      child: const ComparateurPrixApp(),
    ),
  );
}
