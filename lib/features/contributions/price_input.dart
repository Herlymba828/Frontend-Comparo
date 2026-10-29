/// Reading a price typed from a shelf label.
///
/// Mirrors the API rules (contributions/field_reports.py): positive, at most
/// [maxObservedPrice], and no cents in currencies without a minor unit (XAF).
library;

/// ISO 4217 currencies without minor unit.
const zeroDecimalCurrencies = {
  'XAF',
  'XOF',
  'KMF',
  'GNF',
  'RWF',
  'DJF',
  'JPY',
  'KRW',
};

const maxObservedPrice = 10000000;

/// A typed price: its API value ("1500" or "2.50"), or why it is invalid.
class PriceInput {
  const PriceInput.valid(String this.value) : error = null;
  const PriceInput.invalid(String this.error) : value = null;

  final String? value;
  final String? error;

  bool get isValid => value != null;
}

// Spaces a user or a keyboard may put between thousands.
final _spaces = RegExp('[\\s  ]');
// "1500", or thousands grouped by spaces or dots: "1 500", "1.500.000".
final _wholeAmount = RegExp(r'^(\d+|\d{1,3}([ .]\d{3})+)$');
final _decimalAmount = RegExp(r'^\d+([.,]\d{1,2})?$');

PriceInput parseObservedPrice(String raw, {String currency = 'XAF'}) {
  final text = raw.trim().replaceAll(_spaces, ' ');
  if (text.isEmpty) {
    return const PriceInput.invalid('Indiquez le prix affiché.');
  }
  final String value;
  if (zeroDecimalCurrencies.contains(currency.toUpperCase())) {
    if (!_wholeAmount.hasMatch(text)) {
      return PriceInput.invalid(
        RegExp(r'[.,]\d{1,2}$').hasMatch(text)
            ? 'Le prix en ${currency.toUpperCase()} s’écrit sans centimes.'
            : 'Saisissez un nombre, par exemple 1 500.',
      );
    }
    value = text.replaceAll(RegExp('[ .]'), '');
  } else {
    final compact = text.replaceAll(' ', '');
    if (!_decimalAmount.hasMatch(compact)) {
      return const PriceInput.invalid('Saisissez un nombre, par exemple 2,50.');
    }
    value = compact.replaceAll(',', '.');
  }
  final amount = double.parse(value);
  if (amount <= 0) {
    return const PriceInput.invalid('Le prix doit être positif.');
  }
  if (amount > maxObservedPrice) {
    return const PriceInput.invalid(
      'Ce prix est trop élevé pour un article en magasin.',
    );
  }
  return PriceInput.valid(value.replaceFirst(RegExp(r'^0+(?=\d)'), ''));
}

/// A positive quantity typed with a comma or a dot, as an API value.
String? parseQuantity(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  final number = double.tryParse(text);
  return number == null || number <= 0 || number.isNaN || number.isInfinite
      ? null
      : text;
}
