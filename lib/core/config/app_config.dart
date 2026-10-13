import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.apiTimeoutSeconds = 20,
  });

  final String baseUrl;
  final int apiTimeoutSeconds;

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static final current = AppConfig(
    baseUrl: _configuredBaseUrl.isNotEmpty
        ? _configuredBaseUrl
        : defaultTargetPlatform == TargetPlatform.android
            ? 'http://10.0.2.2:8010'
            : 'http://127.0.0.1:8010',
  );
}
