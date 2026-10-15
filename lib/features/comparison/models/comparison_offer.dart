import 'package:json_annotation/json_annotation.dart';

import '../../catalog/models/catalog_product.dart';

part 'comparison_offer.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ProductEquivalenceInfo {
  const ProductEquivalenceInfo({
    required this.id,
    required this.matchKind,
    required this.isStrict,
  });

  final int id;
  final String matchKind;
  final bool isStrict;

  factory ProductEquivalenceInfo.fromJson(Map<String, dynamic> json) =>
      _$ProductEquivalenceInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ProductEquivalenceInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ComparisonGroup {
  const ComparisonGroup({required this.currency, required this.unitCode});

  final String currency;
  final String unitCode;

  factory ComparisonGroup.fromJson(Map<String, dynamic> json) =>
      _$ComparisonGroupFromJson(json);

  Map<String, dynamic> toJson() => _$ComparisonGroupToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ComparisonOffer {
  const ComparisonOffer({
    required this.id,
    required this.product,
    required this.productName,
    required this.amount,
    required this.currency,
    required this.quantity,
    required this.isActive,
    required this.isPromotion,
    required this.isCurrentlyValid,
    required this.comparisonReasons,
    this.merchant,
    this.merchantName,
    this.unitSymbol,
    this.unitCode,
    this.format,
    this.location,
    this.availability,
    this.freshness,
    this.verificationScore,
    this.verificationLevel,
    this.observedAt,
    this.pricePublishedAt,
    this.sourceLabel,
    this.discountAmount,
    this.discountPercent,
    this.conditions,
    this.validFrom,
    this.validTo,
    this.promotionLabel,
    this.promotionDetails,
    this.minQuantity,
    this.publishedAt,
    this.productEquivalence,
    this.normalizedUnitPrice,
    this.normalizedUnit,
    this.comparisonGroup,
  });

  final int id;
  final int product;
  final String productName;
  final int? merchant;
  final String? merchantName;
  final String amount;
  final String currency;
  final String quantity;
  final String? unitSymbol;
  final String? unitCode;
  final CatalogFormat? format;
  final String? location;
  final String? availability;
  final String? freshness;
  final String? verificationScore;
  final String? verificationLevel;
  final DateTime? observedAt;
  final DateTime? pricePublishedAt;
  final String? sourceLabel;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool isActive;
  final bool isPromotion;
  final String? discountAmount;
  final String? discountPercent;
  final String? conditions;
  final String? promotionLabel;
  final String? promotionDetails;
  final String? minQuantity;
  final DateTime? publishedAt;
  final bool isCurrentlyValid;
  final ProductEquivalenceInfo? productEquivalence;
  final String? normalizedUnitPrice;
  final CatalogUnit? normalizedUnit;
  final ComparisonGroup? comparisonGroup;
  final List<String> comparisonReasons;

  factory ComparisonOffer.fromJson(Map<String, dynamic> json) =>
      _$ComparisonOfferFromJson(json);

  Map<String, dynamic> toJson() => _$ComparisonOfferToJson(this);
}
