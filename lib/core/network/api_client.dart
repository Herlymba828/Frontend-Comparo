import 'package:dio/dio.dart';

import '../config/app_config.dart';

Dio createApiClient(AppConfig config) {
  final baseUrl = config.baseUrl.trim();
  if (baseUrl.isEmpty) {
    throw ArgumentError.value(config.baseUrl, 'baseUrl', 'Must not be empty');
  }
  config.validate();

  final timeout = Duration(seconds: config.apiTimeoutSeconds);
  return Dio(
    BaseOptions(
      baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      responseType: ResponseType.json,
    ),
  );
}
