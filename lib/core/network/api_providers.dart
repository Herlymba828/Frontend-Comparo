import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_client.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final client = createApiClient(AppConfig.current);
  ref.onDispose(client.close);
  return client;
});
