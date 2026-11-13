// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comparison_offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductEquivalenceInfo _$ProductEquivalenceInfoFromJson(
  Map<String, dynamic> json,
) => ProductEquivalenceInfo(
  id: (json['id'] as num).toInt(),
  matchKind: json['match_kind'] as String,
  isStrict: json['is_strict'] as bool,
);

Map<String, dynamic> _$ProductEquivalenceInfoToJson(
  ProductEquivalenceInfo instance,
) => <String, dynamic>{
  'id': instance.id,
  'match_kind': instance.matchKind,
  'is_strict': instance.isStrict,
};

ComparisonGroup _$ComparisonGroupFromJson(Map<String, dynamic> json) =>
    ComparisonGroup(
      currency: json['currency'] as String,
      unitCode: json['unit_code'] as String,
    );

Map<String, dynamic> _$ComparisonGroupToJson(ComparisonGroup instance) =>
    <String, dynamic>{
      'currency': instance.currency,
      'unit_code': instance.unitCode,
    };

PriceTrust _$PriceTrustFromJson(Map<String, dynamic> json) => PriceTrust(
  freshnessLevel: json['freshness_level'] as String,
  freshnessLabel: json['freshness_label'] as String,
  confidenceLevel: json['confidence_level'] as String,
  confidenceLabel: json['confidence_label'] as String,
  verdict: json['verdict'] as String,
  verdictLabel: json['verdict_label'] as String,
  explanation: json['explanation'] as String,
  freshnessReferenceAt: json['freshness_reference_at'] == null
      ? null
      : DateTime.parse(json['freshness_reference_at'] as String),
);

Map<String, dynamic> _$PriceTrustToJson(
  PriceTrust instance,
) => <String, dynamic>{
  'freshness_level': instance.freshnessLevel,
  'freshness_label': instance.freshnessLabel,
  'freshness_reference_at': instance.freshnessReferenceAt?.toIso8601String(),
  'confidence_level': instance.confidenceLevel,
  'confidence_label': instance.confidenceLabel,
  'verdict': instance.verdict,
  'verdict_label': instance.verdictLabel,
  'explanation': instance.explanation,
};

ComparisonOffer _$ComparisonOfferFromJson(Map<String, dynamic> json) =>
    ComparisonOffer(
      id: (json['id'] as num).toInt(),
      product: (json['product'] as num).toInt(),
      productName: json['product_name'] as String,
      amount: json['amount'] as String,
      currency: json['currency'] as String,
      quantity: json['quantity'] as String,
      isActive: json['is_active'] as bool,
      isPromotion: json['is_promotion'] as bool,
      isCurrentlyValid: json['is_currently_valid'] as bool,
      comparisonReasons: (json['comparison_reasons'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      merchant: (json['merchant'] as num?)?.toInt(),
      merchantName: json['merchant_name'] as String?,
      unitSymbol: json['unit_symbol'] as String?,
      unitCode: json['unit_code'] as String?,
      format: json['format'] == null
          ? null
          : CatalogFormat.fromJson(json['format'] as Map<String, dynamic>),
      location: json['location'] as String?,
      availability: json['availability'] as String?,
      freshness: json['freshness'] as String?,
      verificationScore: json['verification_score'] as String?,
      verificationLevel: json['verification_level'] as String?,
      observedAt: json['observed_at'] == null
          ? null
          : DateTime.parse(json['observed_at'] as String),
      pricePublishedAt: json['price_published_at'] == null
          ? null
          : DateTime.parse(json['price_published_at'] as String),
      sourceLabel: json['source_label'] as String?,
      discountAmount: json['discount_amount'] as String?,
      discountPercent: json['discount_percent'] as String?,
      conditions: json['conditions'] as String?,
      validFrom: json['valid_from'] == null
          ? null
          : DateTime.parse(json['valid_from'] as String),
      validTo: json['valid_to'] == null
          ? null
          : DateTime.parse(json['valid_to'] as String),
      promotionLabel: json['promotion_label'] as String?,
      promotionDetails: json['promotion_details'] as String?,
      minQuantity: json['min_quantity'] as String?,
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at'] as String),
      productEquivalence: json['product_equivalence'] == null
          ? null
          : ProductEquivalenceInfo.fromJson(
              json['product_equivalence'] as Map<String, dynamic>,
            ),
      normalizedUnitPrice: json['normalized_unit_price'] as String?,
      normalizedUnit: json['normalized_unit'] == null
          ? null
          : CatalogUnit.fromJson(
              json['normalized_unit'] as Map<String, dynamic>,
            ),
      comparisonGroup: json['comparison_group'] == null
          ? null
          : ComparisonGroup.fromJson(
              json['comparison_group'] as Map<String, dynamic>,
            ),
      rank: (json['rank'] as num?)?.toInt(),
      isBestOffer: json['is_best_offer'] as bool? ?? false,
      offerStatus: json['offer_status'] as String?,
      lastConfirmedAt: json['last_confirmed_at'] == null
          ? null
          : DateTime.parse(json['last_confirmed_at'] as String),
      trust: json['trust'] == null
          ? null
          : PriceTrust.fromJson(json['trust'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ComparisonOfferToJson(ComparisonOffer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'product': instance.product,
      'product_name': instance.productName,
      'merchant': instance.merchant,
      'merchant_name': instance.merchantName,
      'amount': instance.amount,
      'currency': instance.currency,
      'quantity': instance.quantity,
      'unit_symbol': instance.unitSymbol,
      'unit_code': instance.unitCode,
      'format': instance.format,
      'location': instance.location,
      'availability': instance.availability,
      'freshness': instance.freshness,
      'verification_score': instance.verificationScore,
      'verification_level': instance.verificationLevel,
      'observed_at': instance.observedAt?.toIso8601String(),
      'price_published_at': instance.pricePublishedAt?.toIso8601String(),
      'source_label': instance.sourceLabel,
      'valid_from': instance.validFrom?.toIso8601String(),
      'valid_to': instance.validTo?.toIso8601String(),
      'is_active': instance.isActive,
      'is_promotion': instance.isPromotion,
      'discount_amount': instance.discountAmount,
      'discount_percent': instance.discountPercent,
      'conditions': instance.conditions,
      'promotion_label': instance.promotionLabel,
      'promotion_details': instance.promotionDetails,
      'min_quantity': instance.minQuantity,
      'published_at': instance.publishedAt?.toIso8601String(),
      'is_currently_valid': instance.isCurrentlyValid,
      'product_equivalence': instance.productEquivalence,
      'normalized_unit_price': instance.normalizedUnitPrice,
      'normalized_unit': instance.normalizedUnit,
      'comparison_group': instance.comparisonGroup,
      'comparison_reasons': instance.comparisonReasons,
      'rank': instance.rank,
      'is_best_offer': instance.isBestOffer,
      'offer_status': instance.offerStatus,
      'last_confirmed_at': instance.lastConfirmedAt?.toIso8601String(),
      'trust': instance.trust,
    };
