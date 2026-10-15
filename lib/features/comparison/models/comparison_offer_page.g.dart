// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comparison_offer_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComparisonOfferPage _$ComparisonOfferPageFromJson(Map<String, dynamic> json) =>
    ComparisonOfferPage(
      count: (json['count'] as num).toInt(),
      results: (json['results'] as List<dynamic>)
          .map((e) => ComparisonOffer.fromJson(e as Map<String, dynamic>))
          .toList(),
      next: json['next'] as String?,
      previous: json['previous'] as String?,
    );

Map<String, dynamic> _$ComparisonOfferPageToJson(
  ComparisonOfferPage instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results,
};
