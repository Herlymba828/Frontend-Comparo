import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/idempotency.dart';

import '../support/fake_api.dart';

void main() {
  test('a key is 128 random bits in hexadecimal', () {
    final key = newIdempotencyKey();
    expect(key, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(newIdempotencyKey(), isNot(key));
  });

  test('the same action keeps its key until it succeeds', () {
    final keys = ActionKeys();
    final pay = (12, 'mobile_money', 'airtel', '077000000');
    final first = keys.keyFor(pay);
    // A retry after a lost answer: same content, same key.
    expect(keys.keyFor((12, 'mobile_money', 'airtel', '077000000')), first);
    // Another content is another action.
    expect(keys.keyFor((12, 'card', 'visa', '')), isNot(first));
    keys.succeeded(pay);
    // Done: paying again later is a new action.
    expect(keys.keyFor(pay), isNot(first));
  });

  test('JsonApi.post sends the key as the Idempotency-Key header', () async {
    final api = FakeApi((_) => ok({'id': 1}));
    await api.jsonApi.post(
      'api/payments/initiate/',
      (json) => json,
      data: {'order_id': 12},
      idempotencyKey: 'abc123',
    );
    await api.jsonApi.post('api/orders/1/cancel/', (json) => json);
    expect(
      api
          .sent('POST', 'api/payments/initiate/')
          .single
          .headers['Idempotency-Key'],
      'abc123',
    );
    expect(
      api.sent('POST', 'api/orders/1/cancel/').single.headers,
      isNot(contains('Idempotency-Key')),
    );
  });
}
