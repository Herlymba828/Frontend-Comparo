import 'package:json_annotation/json_annotation.dart';

import 'catalog_product.dart';

part 'catalog_product_page.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class CatalogProductPage {
  const CatalogProductPage({
    required this.count,
    required this.results,
    this.next,
    this.previous,
  });

  final int count;
  final String? next;
  final String? previous;
  final List<CatalogProduct> results;

  factory CatalogProductPage.fromJson(Map<String, dynamic> json) =>
      _$CatalogProductPageFromJson(json);

  Map<String, dynamic> toJson() => _$CatalogProductPageToJson(this);
}
