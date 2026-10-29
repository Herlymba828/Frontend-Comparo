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
    this.retryAfterSeconds,
  });

  final ApiErrorKind kind;
  final int? statusCode;
  final String? code;
  final String? detail;
  final Map<String, dynamic>? fields;

  /// Seconds to wait before retrying, from a 429 answer's Retry-After.
  final int? retryAfterSeconds;

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
      retryAfterSeconds: int.tryParse(
        exception.response?.headers.value('retry-after') ?? '',
      ),
    );
  }

  /// The API's generic text when only the fields say what is wrong.
  static const _genericInvalid = 'La requête est invalide.';

  /// Messages of the refused fields, in order ("Ce champ est obligatoire.").
  List<String> get fieldMessages => [
    for (final value in (fields ?? const {}).values) ..._messagesOf(value),
  ];

  /// The message about one field, to show under it; null when it is fine.
  String? fieldError(String key) {
    final messages = _messagesOf(fields?[key]);
    return messages.isEmpty ? null : messages.first;
  }

  static List<String> _messagesOf(Object? value) => switch (value) {
    final String text => [text],
    final List<dynamic> items => [
      for (final item in items)
        if (item is String) item,
    ],
    _ => const [],
  };

  String get userMessage {
    if (statusCode == 429) {
      final wait = retryAfterSeconds;
      return wait == null
          ? 'Trop de demandes : patientez un instant avant de réessayer.'
          : 'Trop de demandes : réessayez dans $wait s.';
    }
    final messages = fieldMessages;
    if (messages.isNotEmpty && (detail == null || detail == _genericInvalid)) {
      return messages.take(2).join(' ');
    }
    final known = detail;
    if (known != null) {
      return known;
    }
    return switch (statusCode) {
      401 => 'Votre session a expiré : reconnectez-vous.',
      403 => 'Vous n’avez pas accès à cette action.',
      404 => 'Cet élément est introuvable ou n’existe plus.',
      _ => _kindMessage,
    };
  }

  String get _kindMessage => switch (kind) {
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
