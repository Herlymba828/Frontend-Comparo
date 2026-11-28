import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/errors/offline_error.dart';

void main() {
  group('isOfflineError', () {
    test('no network, an unreachable server and a timeout can wait', () {
      for (final kind in [
        ApiErrorKind.offline,
        ApiErrorKind.network,
        ApiErrorKind.timeout,
      ]) {
        expect(
          isOfflineError(ApiException(kind: kind)),
          isTrue,
          reason: '$kind',
        );
      }
    });

    test('a server error can wait', () {
      expect(
        isOfflineError(
          const ApiException(kind: ApiErrorKind.http, statusCode: 503),
        ),
        isTrue,
      );
    });

    test('a refusal is an answer, not a missing network', () {
      for (final status in [400, 401, 403, 404, 409, 429]) {
        expect(
          isOfflineError(
            ApiException(kind: ApiErrorKind.http, statusCode: status),
          ),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('anything that is not an API error is not a network problem', () {
      expect(isOfflineError(StateError('boom')), isFalse);
    });
  });
}
