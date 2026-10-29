import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../commerce/commerce_models.dart';

class CourierProfile {
  const CourierProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.isAvailable,
    required this.maxActive,
    required this.activeDeliveries,
    required this.zones,
  });

  final int id;
  final int userId;
  final String name;
  final String phone;
  final String vehicle;
  final bool isAvailable;
  final int maxActive;
  final int activeDeliveries;
  final List<String> zones;

  String get vehicleLabel => vehicleLabels[vehicle] ?? vehicle;

  factory CourierProfile.fromJson(Map<String, dynamic> json) {
    final displayName = json.string('display_name');
    return CourierProfile(
      id: json.requireInt('id'),
      userId: json.requireInt('user'),
      name: displayName.isEmpty ? json.string('email') : displayName,
      phone: json.string('phone'),
      vehicle: json.string('vehicle', 'motorbike'),
      isAvailable: json.flag('is_available'),
      maxActive: json.intOrNull('max_active_deliveries') ?? 0,
      activeDeliveries: json.intOrNull('active_deliveries') ?? 0,
      zones: [for (final zone in json.maps('zones')) zone.string('name')],
    );
  }
}

const vehicleLabels = {
  'foot': 'À pied',
  'bicycle': 'Vélo',
  'motorbike': 'Moto',
  'car': 'Voiture',
  'van': 'Utilitaire',
};

final courierRepositoryProvider = Provider<CourierRepository>(
  (ref) => CourierRepository(ref.watch(jsonApiProvider)),
);

final myCourierProfileProvider = FutureProvider.autoDispose<CourierProfile>(
  (ref) => ref.watch(courierRepositoryProvider).getMyCourierProfile(),
);

/// Deliveries assigned to the courier ([available] = false) or open in
/// their zones ([available] = true).
final courierDeliveriesProvider = FutureProvider.autoDispose
    .family<List<Delivery>, bool>(
      (ref, available) => ref
          .watch(courierRepositoryProvider)
          .getCourierDeliveries(available: available),
    );

final courierDeliveryProvider = FutureProvider.autoDispose
    .family<Delivery, int>(
      (ref, id) => ref.watch(courierRepositoryProvider).getDelivery(id),
    );

/// The courier's own profile and the deliveries they carry.
class CourierRepository {
  const CourierRepository(this._api);

  final JsonApi _api;

  // ── Courier ────────────────────────────────────────────────────────────
  Future<CourierProfile> getMyCourierProfile() =>
      _api.getOne('api/delivery/couriers/me/', CourierProfile.fromJson);

  Future<CourierProfile> updateMyCourierProfile({
    bool? isAvailable,
    String? phone,
    String? vehicle,
  }) => _api.patch(
    'api/delivery/couriers/me/',
    CourierProfile.fromJson,
    data: {'is_available': isAvailable, 'phone': phone, 'vehicle': vehicle},
  );

  Future<List<Delivery>> getCourierDeliveries({
    required bool available,
  }) async => await _api.getAll(
    'api/delivery/deliveries/',
    Delivery.fromJson,
    query: {if (available) 'available': 1, 'ordering': '-created_at'},
  );

  Future<Delivery> getDelivery(int id) =>
      _api.getOne('api/delivery/deliveries/$id/', Delivery.fromJson);

  Future<Delivery> claim(int deliveryId) => _api.post(
    'api/delivery/deliveries/$deliveryId/claim/',
    Delivery.fromJson,
  );

  Future<Delivery> updateStatus(
    int deliveryId,
    String status, {
    String note = '',
  }) => _api.post(
    'api/delivery/deliveries/$deliveryId/status/',
    Delivery.fromJson,
    data: {'status': status, 'note': note},
  );

  Future<Delivery> updateLocation(int deliveryId, double lat, double lon) =>
      _api.post(
        'api/delivery/deliveries/$deliveryId/location/',
        Delivery.fromJson,
        data: {'lat': lat.toStringAsFixed(6), 'lon': lon.toStringAsFixed(6)},
      );

  Future<Delivery> recordProof(
    int deliveryId, {
    String photoUrl = '',
    String signatureUrl = '',
    String note = '',
  }) => _api.post(
    'api/delivery/deliveries/$deliveryId/proof/',
    Delivery.fromJson,
    data: {
      if (photoUrl.isNotEmpty) 'proof_photo_url': photoUrl,
      if (signatureUrl.isNotEmpty) 'recipient_signature_url': signatureUrl,
      'note': note,
    },
  );
}
