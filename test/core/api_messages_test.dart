import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/network/json_api.dart';

void main() {
  group('ApiException.userMessage', () {
    test('field errors replace the generic "invalid request" text', () {
      const error = ApiException(
        kind: ApiErrorKind.http,
        statusCode: 400,
        code: 'invalid',
        detail: 'La requête est invalide.',
        fields: {
          'email': ['Un compte avec cette adresse email existe déjà.'],
          'password': ['Ce mot de passe est trop court.'],
        },
      );
      expect(
        error.userMessage,
        'Un compte avec cette adresse email existe déjà. '
        'Ce mot de passe est trop court.',
      );
      expect(error.fieldError('password'), 'Ce mot de passe est trop court.');
      expect(error.fieldError('city'), isNull);
    });

    test('a specific detail is kept as the message', () {
      const error = ApiException(
        kind: ApiErrorKind.http,
        statusCode: 409,
        detail: 'Ce produit a déjà été relevé.',
        fields: {'existing_contribution': 3},
      );
      expect(error.userMessage, 'Ce produit a déjà été relevé.');
      expect(error.fieldMessages, isEmpty);
    });

    test('too many requests says how long to wait', () {
      const error = ApiException(
        kind: ApiErrorKind.http,
        statusCode: 429,
        detail: 'Request was throttled.',
        retryAfterSeconds: 37,
      );
      expect(error.userMessage, 'Trop de demandes : réessayez dans 37 s.');
    });

    test('status codes without detail get a French message', () {
      expect(
        const ApiException(
          kind: ApiErrorKind.http,
          statusCode: 401,
        ).userMessage,
        contains('reconnectez-vous'),
      );
      expect(
        const ApiException(
          kind: ApiErrorKind.http,
          statusCode: 404,
        ).userMessage,
        contains('introuvable'),
      );
    });

    test('Retry-After is read from the response headers', () {
      final error = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/api/auth/login/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/api/auth/login/'),
            statusCode: 429,
            headers: Headers.fromMap({
              'retry-after': ['12'],
            }),
            data: {
              'error': {'code': 'throttled', 'detail': 'Trop de requêtes.'},
            },
          ),
        ),
      );
      expect(error.retryAfterSeconds, 12);
      expect(error.userMessage, 'Trop de demandes : réessayez dans 12 s.');
    });
  });

  test('getAll follows every page', () async {
    final pages = <int>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final page = options.queryParameters['page'] as int;
            pages.add(page);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'count': 3,
                  'next': page < 3 ? 'next' : null,
                  'results': [
                    {'id': page},
                  ],
                },
              ),
            );
          },
        ),
      );
    final items = await JsonApi(dio)
        .getAll('api/orders/', (json) => json['id'] as int);
    expect(items, [1, 2, 3]);
    expect(pages, [1, 2, 3]);
  });
}
