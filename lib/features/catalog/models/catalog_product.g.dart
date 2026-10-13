// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CatalogCategory _$CatalogCategoryFromJson(Map<String, dynamic> json) =>
    CatalogCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      slug: json['slug'] as String,
    );

Map<String, dynamic> _$CatalogCategoryToJson(CatalogCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
    };

CatalogBrand _$CatalogBrandFromJson(Map<String, dynamic> json) => CatalogBrand(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  slug: json['slug'] as String,
  logoUrl: json['logo_url'] as String?,
);

Map<String, dynamic> _$CatalogBrandToJson(CatalogBrand instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'logo_url': instance.logoUrl,
    };

CatalogUnit _$CatalogUnitFromJson(Map<String, dynamic> json) => CatalogUnit(
  id: (json['id'] as num).toInt(),
  code: json['code'] as String,
  symbol: json['symbol'] as String,
  unitType: json['unit_type'] as String,
);

Map<String, dynamic> _$CatalogUnitToJson(CatalogUnit instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'symbol': instance.symbol,
      'unit_type': instance.unitType,
    };

CatalogProduct _$CatalogProductFromJson(Map<String, dynamic> json) =>
    CatalogProduct(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      slug: json['slug'] as String,
      availability: json['availability'] as String,
      isActive: json['is_active'] as bool,
      isVerified: json['is_verified'] as bool,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      category: json['category'] == null
          ? null
          : CatalogCategory.fromJson(json['category'] as Map<String, dynamic>),
      brand: json['brand'] == null
          ? null
          : CatalogBrand.fromJson(json['brand'] as Map<String, dynamic>),
      defaultUnit: json['default_unit'] == null
          ? null
          : CatalogUnit.fromJson(json['default_unit'] as Map<String, dynamic>),
      imageUrl: json['image_url'] as String?,
      priceSnapshot: json['price_snapshot'] as String?,
      priceSnapshotCurrency: json['price_snapshot_currency'] as String?,
      priceSnapshotUpdatedAt: json['price_snapshot_updated_at'] == null
          ? null
          : DateTime.parse(json['price_snapshot_updated_at'] as String),
    );

Map<String, dynamic> _$CatalogProductToJson(CatalogProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'sku': instance.sku,
      'barcode': instance.barcode,
      'category': instance.category,
      'brand': instance.brand,
      'default_unit': instance.defaultUnit,
      'image_url': instance.imageUrl,
      'price_snapshot': instance.priceSnapshot,
      'price_snapshot_currency': instance.priceSnapshotCurrency,
      'price_snapshot_updated_at': instance.priceSnapshotUpdatedAt
          ?.toIso8601String(),
      'availability': instance.availability,
      'is_active': instance.isActive,
      'is_verified': instance.isVerified,
    };
