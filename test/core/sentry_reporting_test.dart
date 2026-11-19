import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/error_reporter.dart';
import 'package:frontend/core/errors/sentry_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _Recorder implements ErrorReporter {
  final sources = <String>[];

  @override
  void report(Object error, StackTrace? stack, {required String source}) =>
      sources.add(source);
}

class _Broken implements ErrorReporter {
  @override
  void report(Object error, StackTrace? stack, {required String source}) =>
      throw StateError('down');
}

void main() {
  group('SentrySettings', () {
    test('is off without a DSN, even with blanks', () {
      expect(const SentrySettings(dsn: '').isEnabled, isFalse);
      expect(const SentrySettings(dsn: '   ').isEnabled, isFalse);
      expect(const SentrySettings(dsn: 'https://k@h.io/1').isEnabled, isTrue);
    });

    test('this build has no DSN: nothing leaves the phone by default', () {
      expect(SentrySettings.fromEnvironment.isEnabled, isFalse);
    });
  });

  group('configureSentryOptions', () {
    late SentryFlutterOptions options;

    setUp(() {
      options = SentryFlutterOptions();
      configureSentryOptions(
        options,
        const SentrySettings(
          dsn: ' https://key@example.invalid/1 ',
          environment: 'staging',
          release: 'comparo@1.2.3+4',
        ),
      );
    });

    test('keeps the project, the environment and the version', () {
      expect(options.dsn, 'https://key@example.invalid/1');
      expect(options.environment, 'staging');
      expect(options.release, 'comparo@1.2.3+4');
    });

    test('sends no personal data, screenshot nor view hierarchy', () {
      expect(options.sendDefaultPii, isFalse);
      expect(options.attachScreenshot, isFalse);
      expect(options.attachViewHierarchy, isFalse);
      expect(options.attachThreads, isFalse);
      expect(options.captureFailedRequests, isFalse);
      expect(options.reportPackages, isFalse);
    });

    test('monitors errors only: no performance, sessions nor taps', () {
      expect(options.tracesSampleRate, 0);
      expect(options.enableAutoPerformanceTracing, isFalse);
      expect(options.enableUserInteractionTracing, isFalse);
      expect(options.enableUserInteractionBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isFalse);
      expect(options.enableAutoSessionTracking, isFalse);
    });

    test('drops every breadcrumb', () {
      final kept = options.beforeBreadcrumb!(
        Breadcrumb(message: '/orders/12?code=123456'),
        Hint(),
      );
      expect(kept, isNull);
    });

    test('scrubs each event before it is sent', () async {
      final event = SentryEvent(user: SentryUser(email: 'a@b.ga'));
      final sent = await options.beforeSend!(event, Hint());
      expect(sent, isNotNull);
      expect(sent!.user, isNull);
    });

    test('an empty release is not sent as an empty string', () {
      final bare = SentryFlutterOptions();
      configureSentryOptions(bare, const SentrySettings(dsn: 'https://k@h/1'));
      expect(bare.release, isNull);
    });
  });

  group('scrubSentryEvent', () {
    test('removes the user, the request and everything that identifies', () {
      final event = SentryEvent(
        user: SentryUser(email: 'a@b.ga', ipAddress: '10.0.0.1'),
        request: SentryRequest(
          url: 'https://api/auth/reset?code=123456',
          headers: {'Authorization': 'Bearer abc'},
        ),
        // ignore: deprecated_member_use
        extra: {'phone': '+24101000000'},
        breadcrumbs: [Breadcrumb(message: 'tap')],
        serverName: 'phone-of-someone',
      );

      final clean = scrubSentryEvent(event, Hint());

      expect(clean.user, isNull);
      expect(clean.request, isNull);
      // ignore: deprecated_member_use
      expect(clean.extra, isNull);
      expect(clean.breadcrumbs, isNull);
      expect(clean.serverName, isNull);
    });

    test('removes secrets from the texts that stay', () {
      final event = SentryEvent(
        message: SentryMessage('failed: Bearer eyJabc.def password=hunter2'),
        exceptions: [
          SentryException(
            type: 'DioException',
            value: 'GET /reset?code=123456 Authorization: Bearer eyJabc.def',
          ),
        ],
      );

      final clean = scrubSentryEvent(event, Hint());

      final texts = [
        clean.message!.formatted,
        clean.exceptions!.single.value!,
      ].join(' ');
      expect(texts, isNot(contains('eyJabc')));
      expect(texts, isNot(contains('hunter2')));
      expect(texts, isNot(contains('123456')));
      // What helps to debug stays.
      expect(clean.exceptions!.single.type, 'DioException');
      expect(clean.exceptions!.single.value, contains('/reset'));
    });

    test('an event without message nor exception is left usable', () {
      final clean = scrubSentryEvent(SentryEvent(), Hint());
      expect(clean.message, isNull);
      expect(clean.exceptions, anyOf(isNull, isEmpty));
    });
  });

  group('CompositeErrorReporter', () {
    test('every reporter gets the error', () {
      final first = _Recorder();
      final second = _Recorder();
      CompositeErrorReporter([first, second])
          .report(StateError('x'), null, source: 'flutter');
      expect(first.sources, ['flutter']);
      expect(second.sources, ['flutter']);
    });

    test('a failing reporter does not stop the next ones', () {
      final after = _Recorder();
      expect(
        () =>
            CompositeErrorReporter([_Broken(), after])
                .report(StateError('x'), null, source: 'platform'),
        returnsNormally,
      );
      expect(after.sources, ['platform']);
    });
  });

  group('SentryErrorReporter', () {
    test('never throws, even when Sentry was not started', () {
      expect(
        () => const SentryErrorReporter().report(
          StateError('x'),
          StackTrace.current,
          source: 'flutter',
        ),
        returnsNormally,
      );
    });
  });
}
