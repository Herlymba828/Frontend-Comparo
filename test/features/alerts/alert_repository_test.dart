import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/alerts/data/alert_repository.dart';

void main() {
  test('creates a price alert using the API contract', () async {
    late RequestOptions request;
    final client = _client((options) {
      request = options;
      return _alert();
    });

    final created = await AlertRepository(client).createAlert(
      productId: 15,
      triggerType: 'price_drop',
      thresholdAmount: '1200.00',
      thresholdCurrency: 'XAF',
      repeat: true,
    );

    expect(request.path, 'api/alerts/');
    expect(request.data, {
      'product_id': 15,
      'trigger_type': 'price_drop',
      'threshold_amount': '1200.00',
      'threshold_currency': 'XAF',
      'notify_channels': ['in_app'],
      'repeat': true,
    });
    expect(created.productName, 'Riz parfumé');
    expect(created.thresholdAmount, '1200.00');
  });

  test('omits the optional threshold amount when it is not provided', () async {
    late RequestOptions request;
    final client = _client((options) {
      request = options;
      return _alert();
    });

    await AlertRepository(client)
        .createAlert(productId: 15, triggerType: 'price_drop');

    expect(request.data.containsKey('threshold_amount'), isFalse);
  });

  test('reads paginated alert results', () async {
    final repository = AlertRepository(
      _client(
        (options) => {
          'count': 1,
          'results': [_alert()],
        },
      ),
    );

    final alerts = await repository.getAlerts();

    expect(alerts, hasLength(1));
    expect(alerts.single.id, 7);
    expect(alerts.single.isActive, isTrue);
  });

  test(
    'pauses, resumes and cancels an alert through its lifecycle routes',
    () async {
      final requests = <RequestOptions>[];
      final repository = AlertRepository(
        _client((options) {
          requests.add(options);
          if (options.method == 'DELETE') {
            return <String, dynamic>{};
          }
          return options.path.endsWith('/pause/')
              ? _alert(status: 'paused', isActive: false)
              : _alert();
        }),
      );

      final paused = await repository.updateStatus(alertId: 7, resume: false);
      final resumed = await repository.updateStatus(alertId: 7, resume: true);
      await repository.cancelAlert(7);

      expect(paused.status, 'paused');
      expect(paused.isActive, isFalse);
      expect(resumed.status, 'active');
      expect(resumed.isActive, isTrue);
      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'POST api/alerts/7/pause/',
        'POST api/alerts/7/resume/',
        'DELETE api/alerts/7/',
      ]);
    },
  );
}

Map<String, dynamic> _alert({String status = 'active', bool isActive = true}) =>
    {
      'id': 7,
      'product': 15,
      'product_name': 'Riz parfumé',
      'trigger_type': 'price_drop',
      'threshold_amount': '1200.00',
      'threshold_currency': 'XAF',
      'status': status,
      'is_active': isActive,
      'repeat': true,
      'trigger_count': 0,
      'last_triggered_at': null,
    };

Dio _client(Map<String, dynamic> Function(RequestOptions) respond) {
  final client = Dio(BaseOptions(baseUrl: 'https://api.example.test/'));
  client.httpClientAdapter = _JsonAdapter(respond);
  return client;
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.respond);

  final Map<String, dynamic> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
