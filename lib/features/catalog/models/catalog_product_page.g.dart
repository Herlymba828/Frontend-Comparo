// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_product_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CatalogProductPage _$CatalogProductPageFromJson(Map<String, dynamic> json) =>
    CatalogProductPage(
      count: (json['count'] as num).toInt(),
      results: (json['results'] as List<dynamic>)
          .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      next: json['next'] as String?,
      previous: json['previous'] as String?,
    );

Map<String, dynamic> _$CatalogProductPageToJson(CatalogProductPage instance) =>
    <String, dynamic>{
      'count': instance.count,
      'next': instance.next,
      'previous': instance.previous,
      'results': instance.results,
    };
