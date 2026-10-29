import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';

/// One store selling the product (`GET /api/comparison/products/<id>/stores/`).
class ProductStore {
  const ProductStore({
    required this.offerId,
    required this.productName,
    required this.merchantName,
    required this.locationName,
    required this.street,
    required this.city,
    required this.phone,
    required this.amount,
    required this.currency,
    required this.quantity,
    required this.unitSymbol,
    required this.availability,
    required this.freshness,
    required this.isPromotion,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.unitPrice,
    this.unitPriceUnit,
  });

  final int offerId;
  final String productName;
  final String merchantName;
  final String locationName;
  final String street;
  final String city;
  final String phone;
  final String amount;
  final String currency;
  final String quantity;
  final String unitSymbol;
  final String availability;
  final String freshness;
  final bool isPromotion;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? unitPrice;
  final String? unitPriceUnit;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get address =>
      [street, city].where((part) => part.isNotEmpty).join(', ');

  factory ProductStore.fromJson(Map<String, dynamic> json) {
    double? number(String key) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      return value is String ? double.tryParse(value) : null;
    }

    return ProductStore(
      offerId: json.requireInt('offer_id'),
      productName: json.string('product_name'),
      merchantName: json.string('merchant_name'),
      locationName: json.string('location_name'),
      street: json.string('street'),
      city: json.string('city'),
      phone: json.string('phone'),
      amount: json.string('amount', '0'),
      currency: json.string('currency', 'XAF'),
      quantity: json.string('quantity', '1'),
      unitSymbol: json.string('unit_symbol'),
      availability: json.string('availability', 'unknown'),
      freshness: json.string('freshness', 'unknown'),
      isPromotion: json.flag('is_promotion'),
      latitude: number('latitude'),
      longitude: number('longitude'),
      distanceKm: number('distance_km'),
      unitPrice: json.stringOrNull('unit_price'),
      unitPriceUnit: json.stringOrNull('unit_price_unit'),
    );
  }
}

/// The user's position, or why it is unavailable.
class UserPosition {
  const UserPosition.found(
    double this.latitude,
    double this.longitude, {
    this.accuracyM,
  }) : problem = null,
       isDenied = false;
  const UserPosition.missing(String this.problem, {this.isDenied = false})
    : latitude = null,
      longitude = null,
      accuracyM = null;

  final double? latitude;
  final double? longitude;

  /// Radius of uncertainty of the fix, in metres, when the device gives it.
  final double? accuracyM;
  final String? problem;

  /// The user (or the device settings) refused access to the position.
  final bool isDenied;

  bool get isKnown => latitude != null;
}

/// Access to the device position, replaceable in tests.
class PositionService {
  const PositionService();

  /// Whether the app may already read the position (no prompt shown).
  Future<bool> isGranted() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } on Exception {
      return false;
    }
  }

  /// Reads the position, asking for the permission if needed.
  Future<UserPosition> locate() => locateUser();
}

final positionServiceProvider = Provider<PositionService>(
  (ref) => const PositionService(),
);

final userPositionProvider = FutureProvider.autoDispose<UserPosition>(
  (ref) => ref.watch(positionServiceProvider).locate(),
);

const _maxFixAge = Duration(minutes: 10);

/// Asks for the position once (permission prompt on first use).
Future<UserPosition> locateUser() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const UserPosition.missing(
        'La localisation est désactivée sur cet appareil.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const UserPosition.missing(
        'Autorisez la localisation pour voir la distance des magasins.',
        isDenied: true,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const UserPosition.missing(
        'La localisation est refusée : modifiez l’autorisation dans les '
        'réglages pour voir les distances.',
        isDenied: true,
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return UserPosition.found(
      position.latitude,
      position.longitude,
      accuracyM: position.accuracy,
    );
  } on Exception {
    // No fresh fix in time (indoors, permission dialogs): the last known
    // position is still good enough to rank nearby stores.
    try {
      final last = await Geolocator.getLastKnownPosition();
      // An old fix may be in another city: only a recent one is trusted.
      if (last != null &&
          DateTime.now().difference(last.timestamp) < _maxFixAge) {
        return UserPosition.found(
          last.latitude,
          last.longitude,
          accuracyM: last.accuracy,
        );
      }
    } on Exception {
      // Fall through to the message below.
    }
    return const UserPosition.missing(
      'Position introuvable pour le moment : magasins triés par prix.',
    );
  }
}

typedef StoresQuery = ({
  int productId,
  double? lat,
  double? lon,
  String ordering,
});

final productStoresProvider = FutureProvider.autoDispose
    .family<List<ProductStore>, StoresQuery>((ref, query) async {
      final api = ref.watch(jsonApiProvider);
      final page = await api.getPage(
        'api/comparison/products/${query.productId}/stores/',
        ProductStore.fromJson,
        query: {
          'lat': query.lat?.toStringAsFixed(6),
          'lon': query.lon?.toStringAsFixed(6),
          'ordering': query.ordering,
        },
      );
      return page.items;
    });
