// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merchant_availability.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MerchantAvailability _$MerchantAvailabilityFromJson(
  Map<String, dynamic> json,
) => MerchantAvailability(
  id: (json['id'] as num).toInt(),
  product: (json['product'] as num).toInt(),
  status: json['status'] as String,
  isAvailable: json['is_available'] as bool,
  productName: json['product_name'] as String?,
  merchant: (json['merchant'] as num?)?.toInt(),
  merchantName: json['merchant_name'] as String?,
  location: (json['location'] as num?)?.toInt(),
  quantityAvailable: json['quantity_available'] as String?,
  observedAt: json['observed_at'] == null
      ? null
      : DateTime.parse(json['observed_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$MerchantAvailabilityToJson(
  MerchantAvailability instance,
) => <String, dynamic>{
  'id': instance.id,
  'product': instance.product,
  'product_name': instance.productName,
  'merchant': instance.merchant,
  'merchant_name': instance.merchantName,
  'location': instance.location,
  'status': instance.status,
  'is_available': instance.isAvailable,
  'quantity_available': instance.quantityAvailable,
  'observed_at': instance.observedAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

MerchantAvailabilityPage _$MerchantAvailabilityPageFromJson(
  Map<String, dynamic> json,
) => MerchantAvailabilityPage(
  count: (json['count'] as num).toInt(),
  results: (json['results'] as List<dynamic>)
      .map((e) => MerchantAvailability.fromJson(e as Map<String, dynamic>))
      .toList(),
  next: json['next'] as String?,
  previous: json['previous'] as String?,
);

Map<String, dynamic> _$MerchantAvailabilityPageToJson(
  MerchantAvailabilityPage instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results,
};
