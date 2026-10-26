import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_client.dart';

void main() {
  test('development uses the platform-specific local API default', () {
    final android = AppConfig.fromEnvironment(
      configuredBaseUrl: '',
      isRelease: false,
      targetPlatform: TargetPlatform.android,
    );
    final other = AppConfig.fromEnvironment(
      configuredBaseUrl: '',
      isRelease: false,
      targetPlatform: TargetPlatform.linux,
    );

    expect(android.baseUrl, 'http://10.0.2.2:8010');
    expect(other.baseUrl, 'http://127.0.0.1:8010');
    expect(() => createApiClient(android), returnsNormally);
  });

  test('release requires a configured public HTTPS URL', () {
    expect(
      () => AppConfig.fromEnvironment(
        configuredBaseUrl: '',
        isRelease: true,
        targetPlatform: TargetPlatform.android,
      ),
      throwsStateError,
    );

    for (final url in [
      'http://api.example.com',
      'https://localhost',
      'https://127.0.0.1:8010',
      'https://10.0.2.2:8010',
      'https://192.168.1.15',
    ]) {
      final config = AppConfig(baseUrl: url, isRelease: true);
      expect(() => createApiClient(config), throwsArgumentError, reason: url);
    }

    expect(
      () => createApiClient(
        const AppConfig(baseUrl: 'https://api.example.com/', isRelease: true),
      ),
      returnsNormally,
    );
  });
}
