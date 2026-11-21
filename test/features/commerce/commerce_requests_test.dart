import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/features/commerce/commerce_repository.dart';
import 'package:frontend/features/courier/courier_repository.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _order() => {
  'id': 7,
  'order_number': 'ORD-2026-0007',
  'status': 'pending',
  'total': '3300.00',
  'currency': 'XAF',
  'delivery_mode': 'delivery',
  'created_at': '2026-11-20T08:00:00Z',
  'items': <Object?>[],
};

Map<String, Object?> _payment({String status = 'pending'}) => {
  'payment_number': 'PAY-2026-1',
  'order': 7,
  'status': status,
  'amount': '3300.00',
  'currency': 'XAF',
  'method': 'mobile_money',
  'provider': 'airtel',
};

Map<String, Object?> _delivery({String status = 'assigned'}) => {
  'id': 5,
  'delivery_number': 'DLV-5',
  'order': 7,
  'status': status,
};

void main() {
  group('money requests carry their idempotency key', () {
    test('checkout sends the key header and what the customer chose', () async {
      final api = FakeApi((_) => ok(_order()));
      final repo = CommerceRepository(api.jsonApi);

      await repo.checkout(
        deliveryMode: 'delivery',
        addressId: 3,
        notes: 'Sonner deux fois',
        idempotencyKey: 'key-checkout',
      );

      final call = api.sent('POST', 'api/orders/checkout/').single;
      expect(call.headers['Idempotency-Key'], 'key-checkout');
      expect(call.data, {
        'delivery_mode': 'delivery',
        'delivery_address_id': 3,
        'notes': 'Sonner deux fois',
        'accept_price_changes': false,
      });
    });

    test('a replay sends the same key, so no second order', () async {
      final api = FakeApi((_) => ok(_order()));
      final repo = CommerceRepository(api.jsonApi);

      for (var attempt = 0; attempt < 2; attempt++) {
        await repo.checkout(deliveryMode: 'pickup', idempotencyKey: 'same-key');
      }

      final keys = api
          .sent('POST', 'api/orders/checkout/')
          .map((call) => call.headers['Idempotency-Key']);
      expect(keys, ['same-key', 'same-key']);
    });

    test('payment and refund carry their own keys', () async {
      final api = FakeApi((_) => ok(_payment()));
      final repo = CommerceRepository(api.jsonApi);

      await repo.initiatePayment(
        orderId: 7,
        method: 'mobile_money',
        provider: 'airtel',
        instrumentHint: '+24106000000',
        idempotencyKey: 'key-pay',
      );
      await repo.refundPayment(
        'PAY-2026-1',
        amount: '500',
        reason: 'Produit abîmé',
        idempotencyKey: 'key-refund',
      );

      final pay = api.sent('POST', 'api/payments/initiate/').single;
      expect(pay.headers['Idempotency-Key'], 'key-pay');
      expect((pay.data as Map)['order_id'], 7);
      final refund = api.sent('POST', 'api/payments/PAY-2026-1/refund/').single;
      expect(refund.headers['Idempotency-Key'], 'key-refund');
      expect((refund.data as Map)['amount'], '500');
    });
  });

  group('order actions', () {
    test('cancelling an order says why', () async {
      final api = FakeApi((_) => ok(_order()));
      await CommerceRepository(api.jsonApi)
          .cancelOrder(7, reason: 'Erreur de commande');

      final call = api.sent('POST', 'api/orders/7/cancel/').single;
      expect((call.data as Map)['reason'], 'Erreur de commande');
    });

    test('a price change is reported, not silently accepted', () {
      final api = FakeApi(
        (_) => (
          status: 409,
          body: {
            'error': {
              'code': 'price_changed',
              'detail': 'Des prix ont changé.',
              'fields': null,
            },
          },
        ),
      );

      expect(
        CommerceRepository(api.jsonApi)
            .checkout(deliveryMode: 'delivery', idempotencyKey: 'k'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 409)
              .having((e) => e.code, 'code', 'price_changed'),
        ),
      );
    });

    test('accepting the new prices is explicit on the second try', () async {
      final api = FakeApi((_) => ok(_order()));
      await CommerceRepository(api.jsonApi).checkout(
        deliveryMode: 'delivery',
        acceptPriceChanges: true,
        idempotencyKey: 'k2',
      );

      final call = api.sent('POST', 'api/orders/checkout/').single;
      expect((call.data as Map)['accept_price_changes'], isTrue);
    });
  });

  group('courier requests', () {
    test('the position goes as six-decimal text', () async {
      final api = FakeApi((_) => ok(_delivery(status: 'in_transit')));
      await CourierRepository(api.jsonApi).updateLocation(5, 0.39, 9.4500004);

      final call = api.sent('POST', 'api/delivery/deliveries/5/location/');
      expect(call.single.data, {'lat': '0.390000', 'lon': '9.450000'});
    });

    test('a status change carries its note', () async {
      final api = FakeApi((_) => ok(_delivery(status: 'failed')));
      await CourierRepository(api.jsonApi)
          .updateStatus(5, 'failed', note: 'Client absent');

      final call = api.sent('POST', 'api/delivery/deliveries/5/status/');
      expect(call.single.data, {'status': 'failed', 'note': 'Client absent'});
    });

    test('a proof sends only the links that were given', () async {
      final api = FakeApi((_) => ok(_delivery(status: 'in_transit')));
      await CourierRepository(api.jsonApi)
          .recordProof(5, photoUrl: 'https://cdn.example.com/p.jpg');

      final body =
          api.sent('POST', 'api/delivery/deliveries/5/proof/').single.data
              as Map;
      expect(body['proof_photo_url'], 'https://cdn.example.com/p.jpg');
      expect(body.containsKey('recipient_signature_url'), isFalse);
    });

    test('a refused consent surfaces as its code', () {
      final api = FakeApi(
        (_) => (
          status: 403,
          body: {
            'error': {
              'code': 'consent_required',
              'detail': 'Votre accord est nécessaire.',
              'fields': null,
            },
          },
        ),
      );

      expect(
        CourierRepository(api.jsonApi).updateLocation(5, 0.39, 9.45),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'consent_required'),
        ),
      );
    });

    test('claiming a delivery posts to its claim route', () async {
      final api = FakeApi((_) => ok(_delivery()));
      await CourierRepository(api.jsonApi).claim(5);

      expect(
        api.sent('POST', 'api/delivery/deliveries/5/claim/'),
        hasLength(1),
      );
    });
  });

  test('every refusal is read from the common error envelope', () {
    final exception = ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(path: 'x'),
        response: Response(
          requestOptions: RequestOptions(path: 'x'),
          statusCode: 409,
          data: {
            'error': {
              'code': 'conflict',
              'detail': 'Déjà pris.',
              'fields': null,
            },
            'request_id': 'abc',
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(exception.code, 'conflict');
    expect(exception.detail, 'Déjà pris.');
  });
}
