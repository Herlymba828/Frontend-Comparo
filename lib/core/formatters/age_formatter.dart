const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// Age d'un relevé, comme dans le design : relatif jusqu'à 7 jours
/// (« il y a 2 h », « hier », « il y a 3 j »), puis absolu (« le 3 nov. »).
String formatAge(DateTime moment, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final elapsed = current.difference(moment);
  if (elapsed.isNegative || elapsed.inHours < 1) {
    return 'il y a moins d’une heure';
  }
  if (elapsed.inHours < 24) {
    return 'il y a ${elapsed.inHours} h';
  }
  if (elapsed.inDays == 1) {
    return 'hier';
  }
  if (elapsed.inDays < 7) {
    return 'il y a ${elapsed.inDays} j';
  }
  final local = moment.toLocal();
  return 'le ${local.day} ${_months[local.month - 1]}';
}
