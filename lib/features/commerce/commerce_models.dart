import '../../core/json/json_reader.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.currentPrice,
    required this.lineTotal,
    required this.currency,
    required this.priceChanged,
  });

  final int id;
  final int productId;
  final String productName;
  final String quantity;
  final String? unitPrice;
  final String? currentPrice;
  final String lineTotal;
  final String currency;
  final bool priceChanged;

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json.requireInt('id'),
    productId: json.requireInt('product'),
    productName: json.string('product_name'),
    quantity: json.string('quantity', '1'),
    unitPrice: json.stringOrNull('unit_price_snapshot'),
    currentPrice: json.stringOrNull('current_price'),
    lineTotal: json.string('line_total', '0'),
    currency: json.string('currency_snapshot', 'XAF'),
    priceChanged: json.flag('price_changed'),
  );
}

class Cart {
  const Cart({
    required this.id,
    required this.merchantId,
    required this.total,
    required this.itemCount,
    required this.items,
  });

  final int id;
  final int? merchantId;
  final String total;
  final int itemCount;
  final List<CartItem> items;

  String get currency => items.isEmpty ? 'XAF' : items.first.currency;

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
    id: json.requireInt('id'),
    merchantId: json.intOrNull('merchant'),
    total: json.string('total', '0'),
    itemCount: json.intOrNull('item_count') ?? 0,
    items: json.maps('items').map(CartItem.fromJson).toList(),
  );
}

class CartValidation {
  const CartValidation({
    required this.valid,
    required this.errors,
    required this.warnings,
  });

  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  static List<String> _messages(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is String)
          item
        else if (item is Map && item['message'] is String)
          item['message'] as String
        else if (item is Map && item['detail'] is String)
          item['detail'] as String,
  ];

  factory CartValidation.fromJson(Map<String, dynamic> json) => CartValidation(
    valid: json.flag('valid'),
    errors: _messages(json['errors']),
    warnings: _messages(json['warnings']),
  );
}

class OrderLine {
  const OrderLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.currency,
  });

  final String productName;
  final String quantity;
  final String unitPrice;
  final String lineTotal;
  final String currency;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    productName: json.string('product_name'),
    quantity: json.string('quantity', '1'),
    unitPrice: json.string('unit_price', '0'),
    lineTotal: json.string('line_total', '0'),
    currency: json.string('currency', 'XAF'),
  );
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.total,
    required this.currency,
    required this.deliveryMode,
    required this.createdAt,
    this.merchantId,
    this.subtotal,
    this.deliveryCost,
    this.paymentStatus = '',
    this.cancelledReason = '',
    this.notes = '',
    this.address,
    this.lines = const [],
  });

  final int id;
  final String number;
  final String status;
  final String total;
  final String currency;
  final String deliveryMode;
  final DateTime? createdAt;
  final int? merchantId;
  final String? subtotal;
  final String? deliveryCost;
  final String paymentStatus;
  final String cancelledReason;
  final String notes;
  final Map<String, dynamic>? address;
  final List<OrderLine> lines;

  bool get isPickup => deliveryMode == 'pickup';

  factory CustomerOrder.fromJson(Map<String, dynamic> json) => CustomerOrder(
    id: json.requireInt('id'),
    number: json.string('order_number'),
    status: json.string('status', 'pending'),
    total: json.string('total', '0'),
    currency: json.string('currency', 'XAF'),
    deliveryMode: json.string('delivery_mode', 'delivery'),
    createdAt: json.dateOrNull('created_at'),
    merchantId: json.intOrNull('merchant'),
    subtotal: json.stringOrNull('subtotal'),
    deliveryCost: json.stringOrNull('delivery_cost'),
    paymentStatus: json.string('payment_status'),
    cancelledReason: json.string('cancelled_reason'),
    notes: json.string('notes'),
    address: json.mapOrNull('delivery_address_snapshot'),
    lines: json.maps('items').map(OrderLine.fromJson).toList(),
  );
}

class Payment {
  const Payment({
    required this.number,
    required this.orderId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.method,
    required this.provider,
    required this.attemptCount,
    required this.maxAttempts,
    required this.isRetryable,
    required this.isTerminal,
    this.amountRefunded = '0',
    this.amountRemaining = '',
    this.failureReason = '',
    this.retryAvailableAt,
  });

  final String number;
  final int orderId;
  final String status;
  final String amount;
  final String currency;
  final String method;
  final String provider;
  final int attemptCount;
  final int maxAttempts;
  final bool isRetryable;
  final bool isTerminal;
  final String amountRefunded;

  /// What can still be refunded (amount minus refunds).
  final String amountRemaining;
  final String failureReason;

  /// After a timeout, when a retry may be sent (null: right away).
  final DateTime? retryAvailableAt;

  bool get isCancellable =>
      status == 'pending' || status == 'declined' || status == 'timeout';
  bool get isRefundable => status == 'captured' || status == 'partial_refund';

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    number: json.requireString('payment_number'),
    orderId: json.requireInt('order'),
    status: json.string('status', 'pending'),
    amount: json.string('amount', '0'),
    currency: json.string('currency', 'XAF'),
    method: json.string('method'),
    provider: json.string('provider'),
    attemptCount: json.intOrNull('attempt_count') ?? 0,
    maxAttempts: json.intOrNull('max_attempts') ?? 0,
    isRetryable: json.flag('is_retryable'),
    isTerminal: json.flag('is_terminal'),
    amountRefunded: json.string('amount_refunded', '0'),
    amountRemaining: json.string('amount_remaining'),
    failureReason: json.string('failure_reason'),
    retryAvailableAt: json.dateOrNull('retry_available_at'),
  );
}

class DeliveryStep {
  const DeliveryStep({required this.status, required this.note, this.at});

  final String status;
  final String note;
  final DateTime? at;

  factory DeliveryStep.fromJson(Map<String, dynamic> json) => DeliveryStep(
    status: json.string('status_after'),
    note: json.string('note'),
    at: json.dateOrNull('created_at'),
  );
}

class Delivery {
  const Delivery({
    required this.id,
    required this.number,
    required this.orderId,
    required this.status,
    this.courierId,
    this.city = '',
    this.street,
    this.recipientName,
    this.recipientPhone,
    this.additionalInfo,
    this.estimatedAt,
    this.deliveredAt,
    this.failureReason = '',
    this.proofPhotoUrl = '',
    this.signatureUrl = '',
    this.steps = const [],
  });

  final int id;
  final String number;
  final int orderId;
  final String status;
  final int? courierId;
  final String city;
  final String? street;
  final String? recipientName;
  final String? recipientPhone;
  final String? additionalInfo;
  final DateTime? estimatedAt;
  final DateTime? deliveredAt;
  final String failureReason;
  final String proofPhotoUrl;
  final String signatureUrl;
  final List<DeliveryStep> steps;

  bool get hasProof => proofPhotoUrl.isNotEmpty || signatureUrl.isNotEmpty;

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    id: json.requireInt('id'),
    number: json.string('delivery_number'),
    orderId: json.requireInt('order'),
    status: json.string('status', 'pending'),
    courierId: json.intOrNull('courier'),
    city: json.string('city'),
    street: json.stringOrNull('street'),
    recipientName: json.stringOrNull('recipient_name'),
    recipientPhone: json.stringOrNull('recipient_phone'),
    additionalInfo: json.stringOrNull('additional_info'),
    estimatedAt: json.dateOrNull('estimated_delivery_at'),
    deliveredAt: json.dateOrNull('delivered_at'),
    failureReason: json.string('failure_reason'),
    proofPhotoUrl: json.string('proof_photo_url'),
    signatureUrl: json.string('recipient_signature_url'),
    steps: json.maps('events').map(DeliveryStep.fromJson).toList(),
  );
}

class Pickup {
  const Pickup({
    required this.id,
    required this.orderId,
    required this.status,
    this.code,
    this.locationName,
    this.readyAt,
    this.expiresAt,
    this.collectedAt,
  });

  final int id;
  final int orderId;
  final String status;

  /// Only the customer (and admins) receive it.
  final String? code;
  final String? locationName;
  final DateTime? readyAt;
  final DateTime? expiresAt;
  final DateTime? collectedAt;

  factory Pickup.fromJson(Map<String, dynamic> json) => Pickup(
    id: json.requireInt('id'),
    orderId: json.requireInt('order'),
    status: json.string('status', 'pending'),
    code: json.stringOrNull('pickup_code'),
    locationName: json.stringOrNull('location_name'),
    readyAt: json.dateOrNull('ready_at'),
    expiresAt: json.dateOrNull('expires_at'),
    collectedAt: json.dateOrNull('collected_at'),
  );
}

class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.street,
    required this.city,
    required this.additionalInfo,
    required this.isDefault,
  });

  final int id;
  final String label;
  final String recipientName;
  final String phone;
  final String street;
  final String city;
  final String additionalInfo;
  final bool isDefault;

  String get summary => [
    if (label.isNotEmpty) label,
    street,
    city,
  ].where((part) => part.isNotEmpty).join(' · ');

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      DeliveryAddress(
        id: json.requireInt('id'),
        label: json.string('label'),
        recipientName: json.string('recipient_name'),
        phone: json.string('phone'),
        street: json.string('street'),
        city: json.string('city'),
        additionalInfo: json.string('additional_info'),
        isDefault: json.flag('is_default'),
      );
}

class ShopLocation {
  const ShopLocation({
    required this.id,
    required this.name,
    required this.street,
    required this.city,
    required this.phone,
    required this.isMain,
    required this.isActive,
  });

  final int id;
  final String name;
  final String street;
  final String city;
  final String phone;
  final bool isMain;
  final bool isActive;

  factory ShopLocation.fromJson(Map<String, dynamic> json) => ShopLocation(
    id: json.requireInt('id'),
    name: json.string('name'),
    street: json.string('street'),
    city: json.string('city'),
    phone: json.string('phone'),
    isMain: json.flag('is_main'),
    isActive: json.flag('is_active', true),
  );
}

const paymentMethodLabels = {
  'mobile_money': 'Mobile Money',
  'card': 'Carte bancaire',
  'cash': 'Espèces au retrait',
};

const paymentProviderLabels = {
  'airtel_money': 'Airtel Money',
  'moov_money': 'Moov Money',
  'manual': 'Paiement manuel',
};
