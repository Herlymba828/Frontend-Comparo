import 'package:json_annotation/json_annotation.dart';

import 'comparison_offer.dart';

part 'comparison_offer_page.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ComparisonOfferPage {
  const ComparisonOfferPage({
    required this.count,
    required this.results,
    this.next,
    this.previous,
  });

  final int count;
  final String? next;
  final String? previous;
  final List<ComparisonOffer> results;

  factory ComparisonOfferPage.fromJson(Map<String, dynamic> json) =>
      _$ComparisonOfferPageFromJson(json);

  Map<String, dynamic> toJson() => _$ComparisonOfferPageToJson(this);
}
