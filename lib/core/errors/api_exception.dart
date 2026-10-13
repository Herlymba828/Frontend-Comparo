import 'package:dio/dio.dart';

enum ApiErrorKind { network, timeout, http, invalidResponse }

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.statusCode,
    this.code,
    this.fields,
  });

  final ApiErrorKind kind;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? fields;

  factory ApiException.fromDio(DioException exception) {
    final responseData = exception.response?.data;
    final error = responseData is Map ? responseData['error'] : null;
    final errorMap = error is Map ? error : null;
    final fields = errorMap?['fields'];

    final kind = switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiErrorKind.timeout,
      DioExceptionType.connectionError ||
      DioExceptionType.cancel => ApiErrorKind.network,
      DioExceptionType.badResponse => ApiErrorKind.http,
      _ => exception.response == null
          ? ApiErrorKind.network
          : ApiErrorKind.http,
    };

    return ApiException(
      kind: kind,
      statusCode: exception.response?.statusCode,
      code: errorMap?['code'] is String ? errorMap!['code'] as String : null,
      fields: fields is Map<String, dynamic> ? fields : null,
    );
  }

  String get userMessage => switch (kind) {
        ApiErrorKind.network => 'Connexion impossible. Vérifiez votre réseau.',
        ApiErrorKind.timeout => 'Le serveur met trop de temps à répondre.',
        ApiErrorKind.http =>
          'Le service est momentanément indisponible. Réessayez.',
        ApiErrorKind.invalidResponse =>
          'La réponse du serveur est invalide. Réessayez plus tard.',
      };

  @override
  String toString() => 'ApiException(kind: $kind, statusCode: $statusCode, '
      'code: $code, fields: $fields)';
}
