class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.apiTimeoutSeconds,
  });

  final String baseUrl;
  final int apiTimeoutSeconds;

  static const AppConfig production = AppConfig(
    baseUrl: 'http://127.0.0.1:8010',
    apiTimeoutSeconds: 20,
  );

  static const AppConfig development = AppConfig(
    baseUrl: 'http://127.0.2.2:8010',
    apiTimeoutSeconds: 20,
  );
}
