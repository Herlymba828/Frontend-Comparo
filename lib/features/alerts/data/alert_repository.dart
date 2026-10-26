import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../models/price_alert.dart';

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository(ref.watch(apiClientProvider));
});

final userAlertsProvider = FutureProvider.autoDispose<List<PriceAlert>>((ref) {
  return ref.watch(alertRepositoryProvider).getAlerts();
});

class AlertRepository {
  const AlertRepository(this._client);

  final Dio _client;

  Future<List<PriceAlert>> getAlerts() async {
    try {
      final response = await _client.get<dynamic>('api/alerts/');
      final data = response.data;
      final records = data is List
          ? data
          : data is Map
          ? data['results']
          : null;
      if (records is! List) {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      }
      return records
          .map(
            (item) =>
                PriceAlert.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on ArgumentError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  Future<PriceAlert> createAlert({
    required int productId,
    required String triggerType,
    String? thresholdAmount,
    String thresholdCurrency = 'XAF',
    bool repeat = false,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        'api/alerts/',
        data: {
          'product_id': productId,
          'trigger_type': triggerType,
          ?(thresholdAmount == null ? null : 'threshold_amount'):
              thresholdAmount,
          'threshold_currency': thresholdCurrency,
          'notify_channels': ['in_app'],
          'repeat': repeat,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      }
      return PriceAlert.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  Future<PriceAlert> updateStatus({
    required int alertId,
    required bool resume,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        'api/alerts/$alertId/${resume ? 'resume' : 'pause'}/',
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(kind: ApiErrorKind.invalidResponse);
      }
      return PriceAlert.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  Future<void> cancelAlert(int alertId) async {
    try {
      await _client.delete<void>('api/alerts/$alertId/');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
