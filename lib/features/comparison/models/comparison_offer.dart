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

/// Trust block computed by the API next to a price (apps/pricing/trust.py):
/// freshness, confidence, a verdict and the sentence that explains it.
@JsonSerializable(fieldRename: FieldRename.snake)
class PriceTrust {
  const PriceTrust({
    required this.freshnessLevel,
    required this.freshnessLabel,
    required this.confidenceLevel,
    required this.confidenceLabel,
    required this.verdict,
    required this.verdictLabel,
    required this.explanation,
    this.freshnessReferenceAt,
  });

  /// fresh, recent or stale.
  final String freshnessLevel;
  final String freshnessLabel;
  final DateTime? freshnessReferenceAt;

  /// high, medium or low.
  final String confidenceLevel;
  final String confidenceLabel;

  /// reliable, to_confirm or doubtful.
  final String verdict;
  final String verdictLabel;

  /// "Confirmé il y a 2 h, vérifié par un modérateur."
  final String explanation;

  factory PriceTrust.fromJson(Map<String, dynamic> json) =>
      _$PriceTrustFromJson(json);

  Map<String, dynamic> toJson() => _$PriceTrustToJson(this);
}

/// Server ranking statuses (apps/comparison/ranking.py).
abstract final class OfferStatus {
  static const current = 'current';
  static const expired = 'expired';
  static const unavailable = 'unavailable';
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
    this.rank,
    this.isBestOffer = false,
    this.offerStatus,
    this.lastConfirmedAt,
    this.trust,
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

  /// Rank inside its comparison group, cheapest first; null when the offer
  /// is not current or its unit cannot be compared.
  final int? rank;

  /// The "meilleur prix vérifié" label, chosen by the server (contract
  /// P0.4): the app no longer computes it.
  @JsonKey(defaultValue: false)
  final bool isBestOffer;

  /// current, expired or unavailable ([OfferStatus]).
  final String? offerStatus;
  final DateTime? lastConfirmedAt;
  final PriceTrust? trust;

  factory ComparisonOffer.fromJson(Map<String, dynamic> json) =>
      _$ComparisonOfferFromJson(json);

  Map<String, dynamic> toJson() => _$ComparisonOfferToJson(this);
}
