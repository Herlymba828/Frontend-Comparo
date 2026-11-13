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
      iconUrl: json['icon_url'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      isActive: json['is_active'] as bool?,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => CatalogCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$CatalogCategoryToJson(CatalogCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'icon_url': instance.iconUrl,
      'sort_order': instance.sortOrder,
      'is_active': instance.isActive,
      'children': instance.children,
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

CatalogFormat _$CatalogFormatFromJson(Map<String, dynamic> json) =>
    CatalogFormat(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      quantity: json['quantity'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$CatalogFormatToJson(CatalogFormat instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'quantity': instance.quantity,
      'description': instance.description,
    };

CurrentPrice _$CurrentPriceFromJson(Map<String, dynamic> json) => CurrentPrice(
  offerId: (json['offer_id'] as num).toInt(),
  merchantId: (json['merchant_id'] as num).toInt(),
  merchantName: json['merchant_name'] as String,
  amount: json['amount'] as String,
  currency: json['currency'] as String,
  unitPrice: json['unit_price'] as String,
  unit: json['unit'] as String,
  isBestOffer: json['is_best_offer'] as bool? ?? false,
);

Map<String, dynamic> _$CurrentPriceToJson(CurrentPrice instance) =>
    <String, dynamic>{
      'offer_id': instance.offerId,
      'merchant_id': instance.merchantId,
      'merchant_name': instance.merchantName,
      'amount': instance.amount,
      'currency': instance.currency,
      'unit_price': instance.unitPrice,
      'unit': instance.unit,
      'is_best_offer': instance.isBestOffer,
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
      defaultFormat: json['default_format'] == null
          ? null
          : CatalogFormat.fromJson(
              json['default_format'] as Map<String, dynamic>,
            ),
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
      priceSnapshot: json['price_snapshot'] as String?,
      priceSnapshotCurrency: json['price_snapshot_currency'] as String?,
      priceSnapshotUpdatedAt: json['price_snapshot_updated_at'] == null
          ? null
          : DateTime.parse(json['price_snapshot_updated_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      offerCount: (json['offer_count'] as num?)?.toInt() ?? 0,
      currentPrices:
          (json['current_prices'] as List<dynamic>?)
              ?.map((e) => CurrentPrice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
      'default_format': instance.defaultFormat,
      'image_url': instance.imageUrl,
      'description': instance.description,
      'price_snapshot': instance.priceSnapshot,
      'price_snapshot_currency': instance.priceSnapshotCurrency,
      'price_snapshot_updated_at': instance.priceSnapshotUpdatedAt
          ?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'availability': instance.availability,
      'is_active': instance.isActive,
      'is_verified': instance.isVerified,
      'offer_count': instance.offerCount,
      'current_prices': instance.currentPrices,
    };
