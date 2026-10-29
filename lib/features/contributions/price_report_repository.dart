import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/api_exception.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../stores/stores_repository.dart';

/// A referenced store a price report can be attached to.
class ReportStore {
  const ReportStore({
    required this.id,
    required this.name,
    required this.merchantName,
    required this.street,
    required this.city,
    this.distanceM,
    this.hasCoordinates = true,
  });

  final int id;
  final String name;
  final String merchantName;
  final String street;
  final String city;
  final int? distanceM;

  /// False for a store nobody has placed yet: users can help locate it.
  final bool hasCoordinates;

  String get address =>
      [street, city].where((part) => part.isNotEmpty).join(', ');

  factory ReportStore.fromJson(Map<String, dynamic> json) => ReportStore(
    id: json.requireInt('id'),
    name: json.string('name'),
    merchantName: json.string('merchant_name'),
    street: json.string('street'),
    city: json.string('city'),
    distanceM: json['distance_m'] is int ? json['distance_m'] as int : null,
    hasCoordinates: json['has_coordinates'] != false,
  );
}

/// Where a community store proposal stands after the user's position.
class StoreProposalResult {
  const StoreProposalResult({
    required this.status,
    required this.sightings,
    required this.required,
    this.store,
  });

  /// pending, created (new store) or located (position found).
  final String status;
  final int sightings;
  final int required;

  /// The created or located store, once decided.
  final ReportStore? store;

  bool get isDecided => status == 'created' || status == 'located';

  factory StoreProposalResult.fromJson(Map<String, dynamic> json) {
    final store = json['store'];
    return StoreProposalResult(
      status: json.string('status', 'pending'),
      sightings: json.intOrNull('sightings_count') ?? 0,
      required: json.intOrNull('required_sightings') ?? 10,
      store: store is Map
          ? ReportStore.fromJson(Map<String, dynamic>.from(store))
          : null,
    );
  }
}

/// The store is already referenced here, or the user already reported it.
class StoreProposalConflict implements Exception {
  const StoreProposalConflict(this.message, {this.existingStore});

  final String message;

  /// Set when the proposed store already exists: it can be chosen instead.
  final ReportStore? existingStore;
}

class ProductSuggestion {
  const ProductSuggestion(this.id, this.name);

  final int id;
  final String name;
}

class UnitOption {
  const UnitOption({
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String code;
  final String name;
  final String symbol;
}

/// Known prices of a product compared with the typed one.
class PriceCheck {
  const PriceCheck({
    required this.sampleSize,
    required this.isOutlier,
    this.medianUnitPrice,
    this.baseUnit = '',
    this.typicalQuantity,
    this.typicalUnit = '',
  });

  final int sampleSize;
  final bool isOutlier;
  final String? medianUnitPrice;
  final String baseUnit;
  final String? typicalQuantity;
  final String typicalUnit;

  factory PriceCheck.fromJson(Map<String, dynamic> json) => PriceCheck(
    sampleSize: json['sample_size'] is int ? json['sample_size'] as int : 0,
    isOutlier: json.flag('is_outlier'),
    medianUnitPrice: json.stringOrNull('median_unit_price'),
    baseUnit: json.string('base_unit_symbol', json.string('base_unit')),
    typicalQuantity: json.stringOrNull('typical_quantity'),
    typicalUnit: json.string('typical_unit'),
  );
}

/// A photo of the price label, already compressed on the device.
class PhotoAttachment {
  const PhotoAttachment({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

enum LocationMethod { gps, manual }

class PriceReportDraft {
  const PriceReportDraft({
    required this.store,
    required this.locationMethod,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.unitCode,
    this.position,
    this.productId,
    this.photo,
    this.displayError = false,
    this.notes = '',
    this.confirmOutlier = false,
  });

  final ReportStore store;
  final LocationMethod locationMethod;
  final UserPosition? position;
  final int? productId;
  final String productName;
  final String price;
  final String quantity;
  final String unitCode;
  final PhotoAttachment? photo;
  final bool displayError;
  final String notes;
  final bool confirmOutlier;

  PriceReportDraft confirmed() => PriceReportDraft(
    store: store,
    locationMethod: locationMethod,
    position: position,
    productId: productId,
    productName: productName,
    price: price,
    quantity: quantity,
    unitCode: unitCode,
    photo: photo,
    displayError: displayError,
    notes: notes,
    confirmOutlier: true,
  );
}

/// The product was already reported in this store within 24 hours (409).
class DuplicateReportException implements Exception {
  const DuplicateReportException({
    required this.message,
    required this.existingId,
    required this.isMine,
  });

  final String message;
  final int? existingId;
  final bool isMine;
}

/// The price is far from the known prices and was not confirmed (400).
class UnusualPriceException implements Exception {
  const UnusualPriceException(this.message, this.check);

  final String message;
  final PriceCheck check;
}

final priceReportRepositoryProvider = Provider<PriceReportRepository>(
  (ref) => PriceReportRepository(ref.watch(jsonApiProvider)),
);

final reportUnitsProvider = FutureProvider.autoDispose<List<UnitOption>>(
  (ref) => ref.watch(priceReportRepositoryProvider).units(),
);

class PriceReportRepository {
  const PriceReportRepository(this._api);

  final JsonApi _api;

  static const _stores = 'api/contributions/stores/';

  Future<List<ReportStore>> nearbyStores(UserPosition position) async =>
      (await _api.getPage(
        _stores,
        ReportStore.fromJson,
        query: {
          'lat': position.latitude?.toStringAsFixed(6),
          'lon': position.longitude?.toStringAsFixed(6),
          'accuracy_m': position.accuracyM?.round(),
        },
      )).items;

  Future<List<ReportStore>> searchStores(String text) async =>
      (await _api.getPage(
        _stores,
        ReportStore.fromJson,
        query: {'search': text},
      )).items;

  Future<List<ProductSuggestion>> searchProducts(String text) async =>
      (await _api.getPage(
        'api/catalog/products/',
        (json) => ProductSuggestion(json.requireInt('id'), json.string('name')),
        query: {'q': text, 'page_size': 6},
      )).items;

  Future<List<UnitOption>> units() async => (await _api.getPage(
    'api/catalog/units/',
    (json) => UnitOption(
      code: json.string('code'),
      name: json.string('name'),
      symbol: json.string('symbol'),
    ),
    query: {'page_size': 100},
  )).items;

  /// Counts the user's position for a store missing from the platform.
  Future<StoreProposalResult> proposeStore({
    required String name,
    required String city,
    required String street,
    required UserPosition position,
  }) => _proposal('api/contributions/stores/propose/', {
    'name': name,
    'city': city,
    'street': street,
    ..._sighting(position),
  });

  /// Counts the user's position inside a referenced store without one.
  Future<StoreProposalResult> locateStore(int storeId, UserPosition position) =>
      _proposal(
        'api/contributions/stores/$storeId/locate/',
        _sighting(position),
      );

  static Map<String, Object?> _sighting(UserPosition position) => {
    'latitude': position.latitude?.toStringAsFixed(6),
    'longitude': position.longitude?.toStringAsFixed(6),
    'accuracy_m': position.accuracyM?.round(),
  };

  Future<StoreProposalResult> _proposal(
    String path,
    Map<String, Object?> data,
  ) async {
    try {
      return await _api.post(path, StoreProposalResult.fromJson, data: data);
    } on ApiException catch (error) {
      final fields = error.fields ?? const {};
      if (error.statusCode == 409) {
        final existing = fields['existing_store'];
        throw StoreProposalConflict(
          error.detail ?? 'Ce magasin est déjà signalé.',
          existingStore: existing is Map
              ? ReportStore.fromJson(Map<String, dynamic>.from(existing))
              : null,
        );
      }
      rethrow;
    }
  }

  Future<PriceCheck> priceCheck({
    required int productId,
    String? price,
    String? quantity,
    String? unitCode,
  }) => _api.getOne(
    'api/contributions/price-check/',
    PriceCheck.fromJson,
    query: {
      'product': productId,
      'price': price,
      'quantity': quantity,
      'unit': unitCode,
    },
  );

  /// Sends the report; returns the id of the created contribution.
  Future<int> submit(PriceReportDraft draft) async {
    final gps = draft.locationMethod == LocationMethod.gps;
    try {
      return await _api.postForm(
        'api/contributions/',
        (json) => json.requireInt('id'),
        fields: {
          'store_id': draft.store.id,
          'location_method': draft.locationMethod.name,
          if (gps) 'latitude': draft.position?.latitude?.toStringAsFixed(6),
          if (gps) 'longitude': draft.position?.longitude?.toStringAsFixed(6),
          if (gps) 'accuracy_m': draft.position?.accuracyM?.round(),
          'product_id': draft.productId,
          'raw_product_name': draft.productName,
          'observed_price': draft.price,
          'currency': 'XAF',
          'quantity': draft.quantity,
          'unit_code': draft.unitCode,
          'display_error': draft.displayError,
          'confirm_outlier': draft.confirmOutlier,
          'notes': draft.notes,
        },
        files: {
          if (draft.photo != null)
            'photo': MultipartFile.fromBytes(
              draft.photo!.bytes,
              filename: draft.photo!.filename,
            ),
        },
      );
    } on ApiException catch (error) {
      throw translateReportError(error);
    }
  }
}

/// Turns the API answers about duplicates and unusual prices into typed
/// exceptions the form can act on; other errors are returned unchanged.
Exception translateReportError(ApiException error) {
  final fields = error.fields ?? const {};
  if (error.statusCode == 409 && error.code == 'duplicate_report') {
    final existing = fields['existing_contribution'];
    return DuplicateReportException(
      message: error.detail ?? 'Ce produit a déjà été relevé ici.',
      existingId: existing is int ? existing : null,
      isMine: fields['existing_is_mine'] == true,
    );
  }
  final check = fields['price_check'];
  if (error.statusCode == 400 && check is Map) {
    final messages = fields['observed_price'];
    return UnusualPriceException(
      messages is List && messages.isNotEmpty
          ? messages.first.toString()
          : 'Ce prix est très éloigné des prix connus.',
      PriceCheck.fromJson(Map<String, dynamic>.from(check)),
    );
  }
  return error;
}

/// A picked photo the server would refuse (format or size).
class PhotoRejected implements Exception {
  const PhotoRejected(this.message);

  final String message;
}

/// Takes or picks a photo of the price label, compressed for upload.
class PhotoPicker {
  const PhotoPicker();

  /// Large enough to read a label, ~300 KB instead of several MB.
  static const maxSide = 1600.0;
  static const quality = 80;

  /// Same limit as the server (CONTRIBUTION_PHOTO_MAX_BYTES).
  static const maxBytes = 2 * 1024 * 1024;

  Future<PhotoAttachment?> pick({required bool fromCamera}) async {
    final file = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
      requestFullMetadata: false,
    );
    if (file == null) {
      return null;
    }
    final name = file.name.toLowerCase();
    if (!(name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png'))) {
      // A PNG is not recompressed by imageQuality, other formats are refused.
      throw const PhotoRejected('Choisissez une photo JPEG ou PNG.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const PhotoRejected(
        'Photo trop lourde (2 Mo au plus) : prenez-la plutôt avec l’appareil '
        'photo.',
      );
    }
    return PhotoAttachment(bytes: bytes, filename: file.name);
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => const PhotoPicker());
