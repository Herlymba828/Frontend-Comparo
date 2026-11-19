import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/error_reporter.dart';
import 'package:frontend/core/errors/global_error_handlers.dart';

class _Recorder implements ErrorReporter {
  final reports = <({Object error, StackTrace? stack, String source})>[];

  @override
  void report(Object error, StackTrace? stack, {required String source}) =>
      reports.add((error: error, stack: stack, source: source));
}

class _Broken implements ErrorReporter {
  @override
  void report(Object error, StackTrace? stack, {required String source}) =>
      throw StateError('the reporter is down');
}

/// The test framework checks that a test leaves the global handlers as it
/// found them.
void _restoreHandlersAfterTest() {
  final flutterOnError = FlutterError.onError;
  final platformOnError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  addTearDown(() {
    FlutterError.onError = flutterOnError;
    PlatformDispatcher.instance.onError = platformOnError;
    ErrorWidget.builder = errorWidgetBuilder;
  });
}

void main() {
  group('global error handlers', () {
    test('a framework error reaches the reporter', () {
      _restoreHandlersAfterTest();
      final recorder = _Recorder();
      installGlobalErrorHandlers(recorder, release: true);

      final stack = StackTrace.current;
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('layout broke'),
          stack: stack,
        ),
      );

      final report = recorder.reports.single;
      expect(report.source, 'flutter');
      expect(report.error, isA<StateError>());
      expect(report.stack, stack);
    });

    test(
      'an async error nobody awaited reaches the reporter and is handled',
      () {
        _restoreHandlersAfterTest();
        final recorder = _Recorder();
        installGlobalErrorHandlers(recorder, release: true);

        final handled = PlatformDispatcher.instance.onError!(
          StateError('lost future'),
          StackTrace.current,
        );

        expect(handled, isTrue);
        expect(recorder.reports.single.source, 'platform');
        expect(recorder.reports.single.error, isA<StateError>());
      },
    );

    test('a broken reporter never throws back into the framework', () {
      _restoreHandlersAfterTest();
      installGlobalErrorHandlers(_Broken(), release: true);

      expect(
        () => FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('x')),
        ),
        returnsNormally,
      );
      expect(
        PlatformDispatcher.instance.onError!(StateError('y'), StackTrace.empty),
        isTrue,
      );
    });

    testWidgets('in release a failed widget shows a neutral message', (
      tester,
    ) async {
      _restoreHandlersAfterTest();
      installGlobalErrorHandlers(_Recorder(), release: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) =>
                ErrorWidget.builder(FlutterErrorDetails(exception: 'boom')),
          ),
        ),
      );

      expect(find.textContaining('Un problème est survenu'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    test('in debug the framework keeps its own error widget', () {
      _restoreHandlersAfterTest();
      final before = ErrorWidget.builder;
      installGlobalErrorHandlers(_Recorder(), release: false);
      expect(ErrorWidget.builder, same(before));
    });
  });

  group('LogErrorReporter', () {
    test('writes the type, the source and the message', () {
      final entries = <String>[];
      LogErrorReporter(sink: entries.add).report(
        const FormatException('bad json'),
        StackTrace.fromString('#0 main (file.dart:1)'),
        source: 'platform',
      );
      expect(entries.single, contains('[platform] FormatException'));
      expect(entries.single, contains('bad json'));
      expect(entries.single, contains('#0 main'));
    });

    test('never writes a token, a password nor a code', () {
      final entries = <String>[];
      LogErrorReporter(sink: entries.add).report(
        Exception(
          'GET /api/auth/reset?code=123456&email=a@b.ga failed with '
          'Authorization: Bearer eyJhbGciOi.abc-def password=hunter2',
        ),
        null,
        source: 'flutter',
      );
      final entry = entries.single;
      expect(entry, isNot(contains('123456')));
      expect(entry, isNot(contains('eyJhbGciOi')));
      expect(entry, isNot(contains('hunter2')));
      expect(entry, contains('Bearer [redacted]'));
      expect(entry, contains('code=[redacted]'));
    });

    test('truncates a very long message', () {
      final entries = <String>[];
      LogErrorReporter(sink: entries.add)
          .report(Exception('x' * 5000), null, source: 'flutter');
      expect(entries.single.length, lessThan(maxReportedMessageLength + 100));
    });
  });
}
