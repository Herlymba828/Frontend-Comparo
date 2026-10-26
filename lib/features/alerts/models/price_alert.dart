class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.productId,
    required this.productName,
    required this.triggerType,
    required this.status,
    required this.isActive,
    required this.repeat,
    this.thresholdAmount,
    this.thresholdCurrency = 'XAF',
    this.triggerCount = 0,
    this.lastTriggeredAt,
  });

  final int id;
  final int productId;
  final String productName;
  final String triggerType;
  final String status;
  final bool isActive;
  final bool repeat;
  final String? thresholdAmount;
  final String thresholdCurrency;
  final int triggerCount;
  final DateTime? lastTriggeredAt;

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final product = json['product'];
    final productName = json['product_name'];
    final triggerType = json['trigger_type'];
    final status = json['status'];
    if (id is! int ||
        product is! int ||
        productName is! String ||
        triggerType is! String ||
        status is! String) {
      throw const FormatException('Invalid alert response.');
    }
    final threshold = json['threshold_amount'];
    final currency = json['threshold_currency'];
    final isActive = json['is_active'];
    final repeat = json['repeat'];
    final triggerCount = json['trigger_count'];
    final lastTriggeredAt = json['last_triggered_at'];
    return PriceAlert(
      id: id,
      productId: product,
      productName: productName,
      triggerType: triggerType,
      status: status,
      isActive: isActive is bool ? isActive : status == 'active',
      repeat: repeat is bool ? repeat : false,
      thresholdAmount: threshold is String ? threshold : null,
      thresholdCurrency: currency is String ? currency : 'XAF',
      triggerCount: triggerCount is int ? triggerCount : 0,
      lastTriggeredAt: lastTriggeredAt is String
          ? DateTime.tryParse(lastTriggeredAt)
          : null,
    );
  }
}
