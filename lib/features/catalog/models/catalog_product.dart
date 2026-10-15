import 'package:json_annotation/json_annotation.dart';

part 'catalog_product.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
    this.sortOrder,
    this.isActive,
    this.children = const [],
  });

  final int id;
  final String name;
  final String slug;
  final String? iconUrl;
  final int? sortOrder;
  final bool? isActive;
  @JsonKey(defaultValue: <CatalogCategory>[])
  final List<CatalogCategory> children;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) =>
      _$CatalogCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$CatalogCategoryToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class CatalogBrand {
  const CatalogBrand({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
  });

  final int id;
  final String name;
  final String slug;
  final String? logoUrl;

  factory CatalogBrand.fromJson(Map<String, dynamic> json) =>
      _$CatalogBrandFromJson(json);

  Map<String, dynamic> toJson() => _$CatalogBrandToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class CatalogUnit {
  const CatalogUnit({
    required this.id,
    required this.code,
    required this.symbol,
    required this.unitType,
  });

  final int id;
  final String code;
  final String symbol;
  final String unitType;

  factory CatalogUnit.fromJson(Map<String, dynamic> json) =>
      _$CatalogUnitFromJson(json);

  Map<String, dynamic> toJson() => _$CatalogUnitToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class CatalogFormat {
  const CatalogFormat({
    required this.id,
    required this.name,
    this.quantity,
    this.description,
  });

  final int id;
  final String name;
  final String? quantity;
  final String? description;

  factory CatalogFormat.fromJson(Map<String, dynamic> json) =>
      _$CatalogFormatFromJson(json);

  Map<String, dynamic> toJson() => _$CatalogFormatToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.availability,
    required this.isActive,
    required this.isVerified,
    this.sku,
    this.barcode,
    this.category,
    this.brand,
    this.defaultUnit,
    this.defaultFormat,
    this.imageUrl,
    this.description,
    this.priceSnapshot,
    this.priceSnapshotCurrency,
    this.priceSnapshotUpdatedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String slug;
  final String? sku;
  final String? barcode;
  final CatalogCategory? category;
  final CatalogBrand? brand;
  final CatalogUnit? defaultUnit;
  final CatalogFormat? defaultFormat;
  final String? imageUrl;
  final String? description;

  // Keep decimal values as strings to avoid binary floating-point rounding.
  final String? priceSnapshot;
  final String? priceSnapshotCurrency;
  final DateTime? priceSnapshotUpdatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String availability;
  final bool isActive;
  final bool isVerified;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) =>
      _$CatalogProductFromJson(json);

  Map<String, dynamic> toJson() => _$CatalogProductToJson(this);
}
