import '../comparison/models/comparison_offer.dart';

String? nonEmptyProductValue(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Source à montrer à l'utilisateur : `null` pour une source absente ou pour
/// un identifiant interne (`frontend-demo:riz-1kg:grocery`), qui ne dit rien
/// à une personne.
String? readableSource(String? value) {
  final source = nonEmptyProductValue(value);
  if (source == null || RegExp(r'^[\w.\-]+(:[^\s:]+)+$').hasMatch(source)) {
    return null;
  }
  return source;
}

/// En-tête d'un groupe d'offres : unité lisible (symbole plutôt que code
/// technique) et mention explicite quand le backend n'a pas pu normaliser.
String productGroupHeading(String? currency, List<ComparisonOffer> offers) {
  final sample = offers.first;
  final unit =
      nonEmptyProductValue(sample.normalizedUnit?.symbol) ??
      nonEmptyProductValue(sample.unitSymbol) ??
      nonEmptyProductValue(sample.comparisonGroup?.unitCode) ??
      nonEmptyProductValue(sample.unitCode);
  final label = [?currency, ?unit].join(' / ');
  final comparable = offers.any((offer) => offer.comparisonGroup != null);
  return comparable
      ? 'Prix comparés en $label'
      : 'Sans prix unitaire comparable ($label)';
}
