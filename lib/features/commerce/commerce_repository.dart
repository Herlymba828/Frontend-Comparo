import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/json_api.dart';
import 'commerce_models.dart';

final commerceRepositoryProvider = Provider<CommerceRepository>(
  (ref) => CommerceRepository(ref.watch(jsonApiProvider)),
);

final cartProvider = FutureProvider.autoDispose<Cart>(
  (ref) => ref.watch(commerceRepositoryProvider).getCart(),
);

final myOrdersProvider = FutureProvider.autoDispose<List<CustomerOrder>>(
  (ref) => ref.watch(commerceRepositoryProvider).getOrders(),
);

final orderProvider = FutureProvider.autoDispose.family<CustomerOrder, int>(
  (ref, id) => ref.watch(commerceRepositoryProvider).getOrder(id),
);

/// Payment, delivery and pickup of one order (each may not exist yet).
final orderFulfilmentProvider = FutureProvider.autoDispose
    .family<OrderFulfilment, int>(
      (ref, orderId) =>
          ref.watch(commerceRepositoryProvider).getFulfilment(orderId),
    );

final addressesProvider = FutureProvider.autoDispose<List<DeliveryAddress>>(
  (ref) => ref.watch(commerceRepositoryProvider).getAddresses(),
);

final shopLocationsProvider = FutureProvider.autoDispose
    .family<List<ShopLocation>, int>(
      (ref, merchantId) =>
          ref.watch(commerceRepositoryProvider).getShopLocations(merchantId),
    );

class OrderFulfilment {
  const OrderFulfilment({this.payment, this.delivery, this.pickup});

  final Payment? payment;
  final Delivery? delivery;
  final Pickup? pickup;
}

class CommerceRepository {
  const CommerceRepository(this._api);

  final JsonApi _api;

  // ── Cart ───────────────────────────────────────────────────────────────
  Future<Cart> getCart() => _api.getOne('api/cart/', Cart.fromJson);

  Future<Cart> addToCart({
    required int productId,
    required String quantity,
    int? offerId,
  }) => _api.post(
    'api/cart/items/',
    Cart.fromJson,
    data: {
      'product_id': productId,
      'quantity': quantity,
      'price_offer_id': offerId,
    },
  );

  Future<Cart> updateQuantity(int itemId, String quantity) => _api.patch(
    'api/cart/items/$itemId/',
    Cart.fromJson,
    data: {'quantity': quantity},
  );

  Future<void> removeItem(int itemId) => _api.delete('api/cart/items/$itemId/');

  Future<void> clearCart() => _api.delete('api/cart/');

  Future<CartValidation> validateCart() =>
      _api.getOne('api/cart/validate/', CartValidation.fromJson);

  // ── Orders ─────────────────────────────────────────────────────────────
  Future<CustomerOrder> checkout({
    required String deliveryMode,
    int? addressId,
    int? pickupLocationId,
    String notes = '',
    bool acceptPriceChanges = false,
  }) => _api.post(
    'api/orders/checkout/',
    CustomerOrder.fromJson,
    data: {
      'delivery_mode': deliveryMode,
      'delivery_address_id': addressId,
      'pickup_location_id': pickupLocationId,
      'notes': notes,
      // Sent once the customer saw the new prices (409 price_changed).
      'accept_price_changes': acceptPriceChanges,
    },
  );

  Future<List<CustomerOrder>> getOrders({
    String? status,
    int? merchantId,
  }) async => await _api.getAll(
    'api/orders/',
    CustomerOrder.fromJson,
    query: {
      'status': status,
      'merchant': merchantId,
      'ordering': '-created_at',
    },
  );

  Future<CustomerOrder> getOrder(int id) =>
      _api.getOne('api/orders/$id/', CustomerOrder.fromJson);

  Future<CustomerOrder> cancelOrder(int id, {String reason = ''}) => _api.post(
    'api/orders/$id/cancel/',
    CustomerOrder.fromJson,
    data: {'reason': reason},
  );

  // ── Payments ───────────────────────────────────────────────────────────
  Future<Payment> initiatePayment({
    required int orderId,
    required String method,
    required String provider,
    String instrumentHint = '',
  }) => _api.post(
    'api/payments/initiate/',
    Payment.fromJson,
    data: {
      'order_id': orderId,
      'method': method,
      'provider': provider,
      'payment_instrument_hint': instrumentHint,
    },
  );

  Future<Payment> retryPayment(String number) =>
      _api.post('api/payments/$number/retry/', Payment.fromJson);

  Future<Payment> cancelPayment(String number, {String reason = ''}) =>
      _api.post(
        'api/payments/$number/cancel/',
        Payment.fromJson,
        data: {'reason': reason},
      );

  Future<Payment> refundPayment(
    String number, {
    String? amount,
    String reason = '',
  }) => _api.post(
    'api/payments/$number/refund/',
    Payment.fromJson,
    data: {'amount': amount, 'reason': reason},
  );

  /// The backend has no per-order filter on these lists: one page of the
  /// caller's records is matched on the order id.
  Future<OrderFulfilment> getFulfilment(int orderId) async {
    final query = {'order': orderId};
    final results = await Future.wait([
      _api.getPage('api/payments/', Payment.fromJson, query: query),
      _api.getPage('api/delivery/deliveries/', (json) => json, query: query),
      _api.getPage('api/delivery/pickups/', Pickup.fromJson, query: query),
    ]);
    final payments = (results[0] as Paged<Payment>).items;
    final deliveries = (results[1] as Paged<Map<String, dynamic>>).items;
    final pickups = (results[2] as Paged<Pickup>).items;

    Delivery? delivery;
    final listed = deliveries.firstOrNull;
    if (listed != null && listed['id'] is int) {
      delivery = await getDelivery(listed['id'] as int);
    }
    return OrderFulfilment(
      payment: payments.firstOrNull,
      delivery: delivery,
      pickup: pickups.firstOrNull,
    );
  }

  Future<Delivery> getDelivery(int id) =>
      _api.getOne('api/delivery/deliveries/$id/', Delivery.fromJson);

  // ── Addresses & pickup points ──────────────────────────────────────────
  Future<List<DeliveryAddress>> getAddresses() async =>
      await _api.getAll('api/delivery/addresses/', DeliveryAddress.fromJson);

  Future<DeliveryAddress> createAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String street,
    required String city,
    String additionalInfo = '',
    bool isDefault = false,
  }) => _api.post(
    'api/delivery/addresses/',
    DeliveryAddress.fromJson,
    data: {
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'street': street,
      'city': city,
      'country': 'GA',
      'additional_info': additionalInfo,
      'is_default': isDefault,
    },
  );

  Future<void> deleteAddress(int id) =>
      _api.delete('api/delivery/addresses/$id/');

  Future<List<ShopLocation>> getShopLocations(int merchantId) async =>
      await _api.getAll(
        'api/merchants/$merchantId/locations/',
        ShopLocation.fromJson,
      );
}
