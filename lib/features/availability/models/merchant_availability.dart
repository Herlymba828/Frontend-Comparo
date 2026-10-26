import 'package:json_annotation/json_annotation.dart';

part 'merchant_availability.g.dart';

/// Disponibilité publique d'un produit chez un marchand
/// (`AvailabilityListSerializer`, `GET /api/availability/`).
@JsonSerializable(fieldRename: FieldRename.snake)
class MerchantAvailability {
  const MerchantAvailability({
    required this.id,
    required this.product,
    required this.status,
    required this.isAvailable,
    this.productName,
    this.merchant,
    this.merchantName,
    this.location,
    this.quantityAvailable,
    this.observedAt,
    this.updatedAt,
  });

  final int id;
  final int product;
  final String? productName;
  final int? merchant;
  final String? merchantName;

  /// Identifiant de localisation ; le nom n'est pas exposé par l'API.
  final int? location;

  /// `available`, `limited`, `unavailable`, `unknown` ou `discontinued`.
  final String status;
  final bool isAvailable;

  /// Quantité décimale telle que renvoyée (sans unité dans l'API).
  final String? quantityAvailable;
  final DateTime? observedAt;
  final DateTime? updatedAt;

  factory MerchantAvailability.fromJson(Map<String, dynamic> json) =>
      _$MerchantAvailabilityFromJson(json);

  Map<String, dynamic> toJson() => _$MerchantAvailabilityToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MerchantAvailabilityPage {
  const MerchantAvailabilityPage({
    required this.count,
    required this.results,
    this.next,
    this.previous,
  });

  final int count;
  final String? next;
  final String? previous;
  final List<MerchantAvailability> results;

  factory MerchantAvailabilityPage.fromJson(Map<String, dynamic> json) =>
      _$MerchantAvailabilityPageFromJson(json);

  Map<String, dynamic> toJson() => _$MerchantAvailabilityPageToJson(this);
}
