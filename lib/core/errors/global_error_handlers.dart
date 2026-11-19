import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'error_reporter.dart';

/// Sends every uncaught error to [reporter]:
/// - errors of the framework (build, layout, painting, gestures);
/// - async errors nobody awaited (`PlatformDispatcher.onError`), which would
///   otherwise vanish in release builds.
///
/// A broken reporter never makes things worse: its own failure is logged and
/// dropped, and the app keeps running. In release, a failed widget shows a
/// neutral message instead of the grey Flutter error box.
void installGlobalErrorHandlers(
  ErrorReporter reporter, {
  bool release = kReleaseMode,
}) {
  FlutterError.onError = (details) {
    if (!release) {
      // Keep the readable dump in the debug console.
      FlutterError.presentError(details);
    }
    _report(reporter, details.exception, details.stack, 'flutter');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _report(reporter, error, stack, 'platform');
    // Handled: the engine must not also terminate the isolate.
    return true;
  };
  if (release) {
    ErrorWidget.builder = friendlyErrorWidgetBuilder;
  }
}

void _report(
  ErrorReporter reporter,
  Object error,
  StackTrace? stack,
  String source,
) {
  try {
    reporter.report(error, stack, source: source);
  } on Object catch (failure) {
    // Reporting must never throw back into the framework.
    developer.log(
      'The error reporter failed: ${failure.runtimeType}',
      name: 'comparo',
      level: 1000,
    );
  }
}

/// What replaces a widget that failed to build, in release builds.
Widget friendlyErrorWidgetBuilder(FlutterErrorDetails details) =>
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Un problème est survenu sur cet écran. '
            'Revenez en arrière ou relancez l’application.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
