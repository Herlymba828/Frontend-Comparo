import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.apiTimeoutSeconds = 20,
    this.isRelease = false,
  });

  final String baseUrl;
  final int apiTimeoutSeconds;
  final bool isRelease;

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static final current = AppConfig.fromEnvironment(
    configuredBaseUrl: _configuredBaseUrl,
    isRelease: kReleaseMode,
    targetPlatform: defaultTargetPlatform,
  );

  factory AppConfig.fromEnvironment({
    required String configuredBaseUrl,
    required bool isRelease,
    required TargetPlatform targetPlatform,
  }) {
    final baseUrl = configuredBaseUrl.trim();
    if (isRelease && baseUrl.isEmpty) {
      throw StateError('API_BASE_URL must be defined for release builds.');
    }

    return AppConfig(
      baseUrl: baseUrl.isNotEmpty
          ? baseUrl
          : targetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8010'
          : 'http://127.0.0.1:8010',
      isRelease: isRelease,
    );
  }

  void validate() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Must be an absolute URL');
    }

    if (!isRelease) {
      return;
    }

    final host = uri.host.toLowerCase();
    final isLocalHost =
        host == 'localhost' ||
        host.endsWith('.localhost') ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '0.0.0.0' ||
        host == '10.0.2.2' ||
        host.endsWith('.local') ||
        _isPrivateIpv4(host) ||
        host.startsWith('fc') ||
        host.startsWith('fd') ||
        host.startsWith('fe80:');
    if (uri.scheme != 'https' || isLocalHost) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Release builds require a public HTTPS API URL.',
      );
    }
  }

  bool _isPrivateIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) {
      return false;
    }
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((octet) => octet == null || octet < 0 || octet > 255)) {
      return false;
    }

    final first = octets[0]!;
    final second = octets[1]!;
    return first == 0 ||
        first == 10 ||
        first == 127 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        (first == 169 && second == 254) ||
        (first == 100 && second >= 64 && second <= 127);
  }
}
