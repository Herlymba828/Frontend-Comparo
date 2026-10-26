String formatPrice(String? amount, String? currency) {
  if (amount == null || amount.trim().isEmpty) {
    return 'Prix non renseigné';
  }

  final value = amount.trim();
  final currencyCode = currency?.trim();
  final match = RegExp(r'^([+-]?)(\d+)(?:[.,](\d+))?$').firstMatch(value);
  var formatted = value;
  if (match != null) {
    final sign = match.group(1)!;
    final digits = match.group(2)!;
    final decimal = match.group(3);
    final grouped = StringBuffer(sign);
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        grouped.write('\u202f');
      }
      grouped.write(digits[index]);
    }
    formatted = decimal == null ? grouped.toString() : '$grouped,$decimal';
  }

  return currencyCode == null || currencyCode.isEmpty
      ? '$formatted — devise non renseignée'
      : '$formatted $currencyCode';
}

/// Devises sans subdivision usuelle : le prix unitaire s'affiche à l'unité.
const _zeroDecimalCurrencies = {'XAF', 'XOF'};

/// Prix unitaire dérivé (ex. `1900.000000` XAF/kg) : contrairement à
/// [formatPrice], qui ne touche jamais au montant d'une offre, il est arrondi
/// (demi supérieur) à l'unité pour le XAF et au centime sinon.
String formatUnitPrice(String? amount, String? currency) {
  final value = amount?.trim();
  if (value == null || value.isEmpty) {
    return formatPrice(value, currency);
  }
  final places = _zeroDecimalCurrencies.contains(currency?.trim().toUpperCase())
      ? 0
      : 2;
  return formatPrice(_roundDecimal(value, places) ?? value, currency);
}

/// Quantité lisible : `500.0000` -> `500`, `1.5000` -> `1,5`.
String formatQuantity(String quantity) {
  final match = RegExp(r'^(\d+)(?:[.,](\d+))?$').firstMatch(quantity.trim());
  if (match == null) {
    return quantity;
  }
  final decimals = (match.group(2) ?? '').replaceFirst(RegExp(r'0+$'), '');
  return decimals.isEmpty ? match.group(1)! : '${match.group(1)},$decimals';
}

/// Arrondi « demi supérieur » d'une chaîne décimale positive, sans passer par
/// un flottant ; `null` si la chaîne n'est pas un décimal simple.
String? _roundDecimal(String value, int places) {
  final match = RegExp(r'^(\d+)(?:[.,](\d+))?$').firstMatch(value);
  if (match == null) {
    return null;
  }
  final integer = match.group(1)!;
  final fraction = (match.group(2) ?? '').padRight(places + 1, '0');
  var digits = BigInt.parse('$integer${fraction.substring(0, places)}');
  if (fraction.codeUnitAt(places) - 0x30 >= 5) {
    digits += BigInt.one;
  }
  final text = digits.toString().padLeft(places + 1, '0');
  if (places == 0) {
    return text;
  }
  final cut = text.length - places;
  return '${text.substring(0, cut)}.${text.substring(cut)}';
}
