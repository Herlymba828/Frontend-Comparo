import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../account/account_repository.dart';
import '../commerce/commerce_models.dart';
import '../courier/courier_repository.dart';

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.description,
    required this.phone,
    required this.email,
    required this.status,
    required this.isVerified,
  });

  final int id;
  final String name;
  final String description;
  final String phone;
  final String email;
  final String status;
  final bool isVerified;

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
    id: json.requireInt('id'),
    name: json.string('name'),
    description: json.string('description'),
    phone: json.string('phone'),
    email: json.string('email'),
    status: json.string('status', 'pending'),
    isVerified: json.flag('is_verified'),
  );
}

class ShopOffer {
  const ShopOffer({
    required this.id,
    required this.productId,
    required this.amount,
    required this.currency,
    required this.isActive,
    required this.isCurrentlyValid,
    required this.label,
    this.validTo,
  });

  final int id;
  final int productId;
  final String amount;
  final String currency;
  final bool isActive;
  final bool isCurrentlyValid;
  final String label;
  final DateTime? validTo;

  factory ShopOffer.fromJson(Map<String, dynamic> json) => ShopOffer(
    id: json.requireInt('id'),
    productId: json.requireInt('product'),
    amount: json.string('amount', '0'),
    currency: json.string('currency', 'XAF'),
    isActive: json.flag('is_active'),
    isCurrentlyValid: json.flag('is_currently_valid'),
    label: json.string('promotion_label'),
    validTo: json.dateOrNull('valid_to'),
  );
}

class ShopPrice {
  const ShopPrice({
    required this.id,
    required this.productId,
    required this.productName,
    required this.amount,
    required this.currency,
    required this.quantity,
    required this.unit,
    required this.status,
  });

  final int id;
  final int productId;
  final String productName;
  final String amount;
  final String currency;
  final String quantity;
  final String unit;
  final String status;

  factory ShopPrice.fromJson(Map<String, dynamic> json) => ShopPrice(
    id: json.requireInt('id'),
    productId: json.requireInt('product'),
    productName: json.string('product_name'),
    amount: json.string('amount', '0'),
    currency: json.string('currency', 'XAF'),
    quantity: json.string('quantity', '1'),
    unit: json.string('unit_symbol'),
    status: json.string('status', 'draft'),
  );
}

class StockLine {
  const StockLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.status,
    this.quantity,
  });

  final int id;
  final int productId;
  final String productName;
  final String status;
  final String? quantity;

  factory StockLine.fromJson(Map<String, dynamic> json) => StockLine(
    id: json.requireInt('id'),
    productId: json.requireInt('product'),
    productName: json.string('product_name'),
    status: json.string('status', 'unknown'),
    quantity: json.stringOrNull('quantity_available'),
  );
}

class NamedRef {
  const NamedRef(this.id, this.name);

  final int id;
  final String name;
}

final merchantRepositoryProvider = Provider<MerchantRepository>(
  (ref) => MerchantRepository(ref.watch(jsonApiProvider)),
);

/// The caller's shop, or null when they have not registered one.
final myShopProvider = FutureProvider.autoDispose<Shop?>(
  (ref) => ref.watch(merchantRepositoryProvider).getMyShop(),
);

final shopOrdersProvider = FutureProvider.autoDispose
    .family<List<CustomerOrder>, int>(
      (ref, shopId) => ref.watch(merchantRepositoryProvider).getOrders(shopId),
    );

final shopPricesProvider = FutureProvider.autoDispose
    .family<List<ShopPrice>, int>(
      (ref, shopId) => ref.watch(merchantRepositoryProvider).getPrices(shopId),
    );

final shopOffersProvider = FutureProvider.autoDispose
    .family<List<ShopOffer>, int>(
      (ref, shopId) => ref.watch(merchantRepositoryProvider).getOffers(shopId),
    );

final shopStockProvider = FutureProvider.autoDispose
    .family<List<StockLine>, int>(
      (ref, shopId) => ref.watch(merchantRepositoryProvider).getStock(shopId),
    );

final priceTypesProvider = FutureProvider.autoDispose<List<NamedRef>>(
  (ref) => ref.watch(merchantRepositoryProvider).getPriceTypes(),
);

final unitsProvider = FutureProvider.autoDispose<List<NamedRef>>(
  (ref) => ref.watch(merchantRepositoryProvider).getUnits(),
);

/// Couriers available to carry one of the shop's deliveries.
final availableCouriersProvider =
    FutureProvider.autoDispose<List<CourierProfile>>(
      (ref) => ref.watch(merchantRepositoryProvider).getCouriers(),
    );

/// Complaints filed against the shop.
final receivedComplaintsProvider = FutureProvider.autoDispose<List<Complaint>>(
  (ref) => ref.watch(merchantRepositoryProvider).getReceivedComplaints(),
);

final receivedComplaintProvider = FutureProvider.autoDispose
    .family<Complaint, int>(
      (ref, id) => ref.watch(merchantRepositoryProvider).getComplaint(id),
    );

class MerchantRepository {
  MerchantRepository(this._api);

  final JsonApi _api;

  Future<Shop?> getMyShop() async {
    try {
      return await _api.getOne('api/merchants/me/', Shop.fromJson);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<Shop> createShop({
    required String name,
    String description = '',
    String phone = '',
  }) => _api.post(
    'api/merchants/',
    Shop.fromJson,
    data: {'name': name, 'description': description, 'phone': phone},
  );

  Future<void> updateShop(
    int id, {
    String? name,
    String? description,
    String? phone,
  }) => _api.patch(
    'api/merchants/$id/',
    (json) => json,
    data: {'name': name, 'description': description, 'phone': phone},
  );

  Future<void> addLocation(
    int shopId, {
    required String name,
    required String street,
    required String city,
    String phone = '',
    bool isMain = false,
    double? latitude,
    double? longitude,
  }) => _api.post(
    'api/merchants/$shopId/locations/',
    (json) => json,
    data: {
      'name': name,
      'street': street,
      'city': city,
      'country': 'GA',
      'phone': phone,
      'is_main': isMain,
      // Without coordinates the store never shows "nearby" nor accepts
      // located price reports.
      'latitude': latitude?.toStringAsFixed(6),
      'longitude': longitude?.toStringAsFixed(6),
    },
  );

  Future<void> setLocationActive(int shopId, int locationId, bool active) =>
      _api.patch(
        'api/merchants/$shopId/locations/$locationId/',
        (json) => json,
        data: {'is_active': active},
      );

  Future<void> setMainLocation(int shopId, int locationId) =>
      _api.send('api/merchants/$shopId/locations/$locationId/set_main/');

  Future<List<CustomerOrder>> getOrders(int shopId) async => await _api.getAll(
    'api/orders/',
    CustomerOrder.fromJson,
    query: {'merchant': shopId, 'ordering': '-created_at'},
  );

  Future<List<ShopPrice>> getPrices(int shopId) async => await _api.getAll(
    'api/pricing/observations/',
    ShopPrice.fromJson,
    query: {'merchant': shopId, 'ordering': '-observed_at'},
  );

  Future<List<ShopOffer>> getOffers(int shopId) async => await _api.getAll(
    'api/pricing/offers/',
    ShopOffer.fromJson,
    query: {'merchant': shopId},
  );

  /// Submits the price (reviewed by a moderator) and its offer: the offer can
  /// be published once the price is published.
  Future<void> createOffer({
    required int shopId,
    required int productId,
    required int priceTypeId,
    required int unitId,
    required String amount,
    required String quantity,
    String label = '',
  }) async {
    // A device clock a few minutes ahead would date the price in the future.
    final now = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
    final key = '$shopId/$productId/$priceTypeId/$unitId/$amount/$quantity';
    final price =
        _sentPrices[key] ??
        await _api.post<int>(
          'api/pricing/observations/',
          (json) => json.requireInt('id'),
          data: {
            'product_id': productId,
            'price_type_id': priceTypeId,
            'merchant_id': shopId,
            'amount': amount,
            'currency': 'XAF',
            'quantity': quantity,
            'unit_id': unitId,
            'observed_at': now.toIso8601String(),
            'source_label': 'Espace marchand',
          },
        );
    // Kept until the offer exists: a retry after a failed second call reuses
    // this price instead of submitting a duplicate.
    _sentPrices[key] = price;
    await _api.post(
      'api/pricing/offers/',
      (json) => json,
      data: {
        'price': price,
        'product': productId,
        'merchant': shopId,
        'valid_from': now.toIso8601String(),
        'promotion_label': label,
      },
    );
    _sentPrices.remove(key);
  }

  /// Prices submitted whose offer is not created yet, by form values.
  final Map<String, int> _sentPrices = {};

  Future<void> publishOffer(int offerId) =>
      _api.send('api/pricing/offers/$offerId/publish/');

  Future<List<StockLine>> getStock(int shopId) async => await _api.getAll(
    'api/availability/',
    StockLine.fromJson,
    query: {'merchant': shopId},
  );

  Future<void> setStock({
    required int shopId,
    required int productId,
    required String status,
    String? quantity,
    int? existingId,
  }) {
    final data = <String, Object?>{
      'status': status,
      'quantity_available': (quantity ?? '').isEmpty ? null : quantity,
    };
    if (existingId != null) {
      return _api.patch(
        'api/availability/$existingId/',
        (json) => json,
        data: data,
        // An emptied quantity goes back to a qualitative status only.
        clearable: const {'quantity_available'},
      );
    }
    return _api.post(
      'api/availability/',
      (json) => json,
      data: {...data, 'product_id': productId, 'merchant_id': shopId},
    );
  }

  Future<List<NamedRef>> getPriceTypes() async => await _api.getAll(
    'api/pricing/types/',
    (json) => NamedRef(json.requireInt('id'), json.string('name')),
  );

  Future<List<NamedRef>> getUnits() async => (await _api.getPage(
    'api/catalog/units/',
    (json) => NamedRef(
      json.requireInt('id'),
      '${json.string('name')} (${json.string('symbol')})',
    ),
    query: {'page_size': 100},
  )).items;

  Future<List<NamedRef>> searchProducts(String query) async =>
      (await _api.getPage(
        'api/catalog/products/',
        (json) => NamedRef(json.requireInt('id'), json.string('name')),
        query: {'q': query, 'page_size': 20},
      )).items;

  // ── Fulfilment ──────────────────────────────────────────────────────────
  Future<void> markPickupReady(int pickupId) =>
      _api.send('api/delivery/pickups/$pickupId/ready/');

  Future<void> confirmPickup(int pickupId, String code) => _api.send(
    'api/delivery/pickups/$pickupId/confirm/',
    data: {'pickup_code': code.trim()},
  );

  Future<void> assignCourier(int deliveryId, int courierUserId) => _api.send(
    'api/delivery/deliveries/$deliveryId/assign/',
    data: {'courier_id': courierUserId},
  );

  Future<List<CourierProfile>> getCouriers() async => await _api.getAll(
    'api/delivery/couriers/',
    CourierProfile.fromJson,
    query: {'available': 1},
  );

  // ── Complaints against the shop ─────────────────────────────────────────
  Future<List<Complaint>> getReceivedComplaints() async => await _api.getAll(
    'api/disputes/',
    Complaint.fromJson,
    query: {'scope': 'received'},
  );

  Future<Complaint> getComplaint(int id) =>
      _api.getOne('api/disputes/$id/', Complaint.fromJson);

  /// The shop's answer, read by the support agent deciding the complaint.
  Future<void> respondToComplaint(int id, String response) => _api.send(
    'api/disputes/$id/respond/',
    data: {'response': response.trim()},
  );
}
