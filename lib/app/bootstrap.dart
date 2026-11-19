import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../core/errors/error_reporter.dart';
import '../core/errors/global_error_handlers.dart';
import '../core/errors/sentry_reporting.dart';
import '../features/contributions/report_outbox.dart';
import 'app.dart';

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
  runApp(const ProviderScope(child: _OfflineSync(child: ComparateurPrixApp())));
}

/// Keeps the offline queue alive for the whole session: reports left from a
/// previous session leave at start, the others when the network is back.
class _OfflineSync extends ConsumerStatefulWidget {
  const _OfflineSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_OfflineSync> createState() => _OfflineSyncState();
}

class _OfflineSyncState extends ConsumerState<_OfflineSync> {
  @override
  void initState() {
    super.initState();
    ref.read(reportOutboxProvider.notifier).sync();
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps the queue (and its reconnection listener) alive.
    ref.watch(reportOutboxProvider);
    return widget.child;
  }
}
