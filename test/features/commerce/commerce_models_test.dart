import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/account/account_repository.dart';
import 'package:frontend/features/commerce/commerce_models.dart';
import 'package:frontend/features/identity/models/auth_user.dart';
import 'package:frontend/features/courier/courier_repository.dart';

void main() {
  test('cart and its lines', () {
    final cart = Cart.fromJson({
      'id': 4,
      'merchant': 2,
      'total': '3300.00',
      'item_count': 2,
      'items': [
        {
          'id': 9,
          'product': 3,
          'product_name': 'Riz complet',
          'quantity': '2.000',
          'unit_price_snapshot': '1650.00',
          'current_price': '1650.00',
          'line_total': '3300.00',
          'currency_snapshot': 'XAF',
          'price_changed': false,
        },
      ],
    });
    expect(cart.merchantId, 2);
    expect(cart.items.single.quantity, '2.000');
    expect(cart.currency, 'XAF');
  });

  test('order detail with its delivery address snapshot', () {
    final order = CustomerOrder.fromJson({
      'id': 1,
      'order_number': 'ORD-2026-AB12',
      'status': 'pending',
      'total': '3300.00',
      'currency': 'XAF',
      'delivery_mode': 'pickup',
      'created_at': '2026-10-27T08:00:00Z',
      'delivery_address_snapshot': null,
      'items': [
        {
          'product_name': 'Riz',
          'quantity': '2.000',
          'unit_price': '1650.00',
          'line_total': '3300.00',
          'currency': 'XAF',
        },
      ],
    });
    expect(order.isPickup, isTrue);
    expect(order.lines.single.productName, 'Riz');
    expect(order.createdAt, isNotNull);
  });

  test('payment actions follow its status', () {
    final payment = Payment.fromJson({
      'payment_number': 'PAY-2026-1',
      'order': 1,
      'status': 'captured',
      'amount': '3300.00',
      'currency': 'XAF',
      'method': 'mobile_money',
      'provider': 'airtel_money',
      'attempt_count': 1,
      'max_attempts': 3,
      'is_retryable': false,
      'is_terminal': true,
    });
    expect(payment.isRefundable, isTrue);
    expect(payment.isCancellable, isFalse);
  });

  test('delivery hides what the API masks and reads its steps', () {
    final delivery = Delivery.fromJson({
      'id': 5,
      'delivery_number': 'DEL-2026-1',
      'order': 1,
      'status': 'in_transit',
      'courier': 7,
      'recipient_phone': null,
      'proof_photo_url': '',
      'recipient_signature_url': 'https://example.invalid/s.png',
      'events': [
        {
          'status_after': 'assigned',
          'note': '',
          'created_at': '2026-10-27T08:00:00Z',
        },
      ],
    });
    expect(delivery.recipientPhone, isNull);
    expect(delivery.hasProof, isTrue);
    expect(delivery.steps.single.status, 'assigned');
  });

  test('pickup code is only present for the customer', () {
    final merchantView = Pickup.fromJson({
      'id': 2,
      'order': 1,
      'status': 'ready',
      'pickup_code': null,
    });
    expect(merchantView.code, isNull);
  });

  test('courier profile, contribution and user roles', () {
    final courier = CourierProfile.fromJson({
      'id': 1,
      'user': 7,
      'email': 'c@x.ga',
      'display_name': '',
      'vehicle': 'car',
      'is_available': true,
      'max_active_deliveries': 3,
      'active_deliveries': 1,
      'zones': [
        {'name': 'Libreville'},
      ],
    });
    expect(courier.name, 'c@x.ga');
    expect(courier.vehicleLabel, 'Voiture');

    final contribution = Contribution.fromJson({
      'id': 3,
      'raw_product_name': 'Riz',
      'observed_price': '700.00',
      'confirmations_count': 1,
      'rejections_count': 0,
      'required_confirmations': 3,
      'status': 'pending',
    });
    expect(contribution.required, 3);

    final user = AuthUser.fromJson({
      'id': 1,
      'email': 'a@x.ga',
      'display_name': 'A',
      'email_verified': false,
      'roles': ['consumer', 'courier'],
    });
    expect(user.hasRole('courier'), isTrue);
    expect(user.hasRole('merchant'), isFalse);
  });
}
