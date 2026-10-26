import 'package:dio/dio.dart';

enum ApiErrorKind {
  /// L'appareil n'a aucun accès réseau.
  offline,

  /// Le réseau est présent mais le serveur ne répond pas.
  network,
  timeout,
  http,
  invalidResponse,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.statusCode,
    this.code,
    this.detail,
    this.fields,
  });

  final ApiErrorKind kind;
  final int? statusCode;
  final String? code;
  final String? detail;
  final Map<String, dynamic>? fields;

  factory ApiException.fromDio(DioException exception) {
    final responseData = exception.response?.data;
    final error = responseData is Map ? responseData['error'] : null;
    final errorMap = error is Map ? error : null;
    final fields = errorMap?['fields'];
    // Some views answer {"detail": ...} without the common envelope.
    final detail =
        errorMap?['detail'] ??
        (responseData is Map ? responseData['detail'] : null);

    final kind = switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiErrorKind.timeout,
      DioExceptionType.connectionError ||
      DioExceptionType.cancel => ApiErrorKind.network,
      DioExceptionType.badResponse => ApiErrorKind.http,
      _ =>
        exception.response == null ? ApiErrorKind.network : ApiErrorKind.http,
    };

    return ApiException(
      kind: kind,
      statusCode: exception.response?.statusCode,
      code: errorMap?['code'] is String ? errorMap!['code'] as String : null,
      detail: detail is String ? detail : null,
      fields: fields is Map<String, dynamic> ? fields : null,
    );
  }

  String get userMessage =>
      detail ??
      switch (kind) {
        ApiErrorKind.offline =>
          'Vous êtes hors ligne. Vérifiez votre connexion internet.',
        ApiErrorKind.network =>
          'Le serveur est injoignable pour le moment. Réessayez plus tard.',
        ApiErrorKind.timeout => 'Le serveur met trop de temps à répondre.',
        ApiErrorKind.http =>
          'Le service est momentanément indisponible. Réessayez.',
        ApiErrorKind.invalidResponse =>
          'La réponse du serveur est invalide. Réessayez plus tard.',
      };

  @override
  String toString() =>
      'ApiException(kind: $kind, statusCode: $statusCode, '
      'code: $code, detail: $detail, fields: $fields)';
}
