import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../catalog/models/catalog_product.dart';
import '../identity/data/auth_providers.dart';

/// How the best price of a followed product moved since it was followed.
enum PriceTrend { down, stable, up }

PriceTrend? _trendOf(String? value) => switch (value) {
  'down' => PriceTrend.down,
  'stable' => PriceTrend.stable,
  'up' => PriceTrend.up,
  _ => null,
};

/// A product the user follows, with the price move since it was added.
class FavoriteProduct {
  const FavoriteProduct({
    required this.product,
    this.changePercent,
    this.trend,
  });

  final CatalogProduct product;

  /// Signed percentage as sent by the API ("-8.5"); null when unknown.
  final String? changePercent;
  final PriceTrend? trend;

  factory FavoriteProduct.fromJson(Map<String, dynamic> json) {
    final product = json.mapOrNull('product');
    if (product == null) {
      throw const FormatException('Favourite without a product.');
    }
    return FavoriteProduct(
      product: CatalogProduct.fromJson(product),
      changePercent: json.stringOrNull('change_percent'),
      trend: _trendOf(json.stringOrNull('trend')),
    );
  }
}

/// A shop the user follows.
class FavoriteShop {
  const FavoriteShop({
    required this.merchantId,
    required this.name,
    this.isVerified = false,
    this.offerCount = 0,
  });

  final int merchantId;
  final String name;
  final bool isVerified;
  final int offerCount;

  factory FavoriteShop.fromJson(Map<String, dynamic> json) {
    final merchant = json.mapOrNull('merchant');
    if (merchant == null) {
      throw const FormatException('Favourite without a shop.');
    }
    return FavoriteShop(
      merchantId: merchant.requireInt('id'),
      name: merchant.string('name'),
      isVerified: merchant.flag('is_verified'),
      offerCount: json.intOrNull('offer_count') ?? 0,
    );
  }
}

/// Ids of what the user follows: enough to fill the hearts of a screen.
class FavoriteIds {
  const FavoriteIds({this.productIds = const {}, this.merchantIds = const {}});

  final Set<int> productIds;
  final Set<int> merchantIds;

  factory FavoriteIds.fromJson(Map<String, dynamic> json) => FavoriteIds(
    productIds: _ints(json['product_ids']),
    merchantIds: _ints(json['merchant_ids']),
  );

  static Set<int> _ints(Object? value) =>
      value is List ? value.whereType<int>().toSet() : const {};
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(jsonApiProvider)),
);

class FavoritesRepository {
  const FavoritesRepository(this._api);

  final JsonApi _api;

  Future<FavoriteIds> ids() =>
      _api.getOne('api/favorites/', FavoriteIds.fromJson);

  Future<List<FavoriteProduct>> products() =>
      _api.getAll('api/favorites/products/', FavoriteProduct.fromJson);

  Future<List<FavoriteShop>> shops() =>
      _api.getAll('api/favorites/merchants/', FavoriteShop.fromJson);

  // The answer (the favourite) is not needed: following only has to succeed.
  Future<void> followProduct(int productId) =>
      _api.send('api/favorites/products/', data: {'product_id': productId});

  Future<void> unfollowProduct(int productId) =>
      _api.delete('api/favorites/products/$productId/');

  Future<void> followShop(int merchantId) =>
      _api.send('api/favorites/merchants/', data: {'merchant_id': merchantId});

  Future<void> unfollowShop(int merchantId) =>
      _api.delete('api/favorites/merchants/$merchantId/');
}

/// What the user follows; empty for a visitor (nothing to ask the API).
final favoriteIdsProvider = FutureProvider.autoDispose<FavoriteIds>((
  ref,
) async {
  if (ref.watch(authSessionProvider).value == null) {
    return const FavoriteIds();
  }
  return ref.watch(favoritesRepositoryProvider).ids();
});

final favoriteProductsProvider =
    FutureProvider.autoDispose<List<FavoriteProduct>>(
      (ref) => ref.watch(favoritesRepositoryProvider).products(),
    );

final favoriteShopsProvider = FutureProvider.autoDispose<List<FavoriteShop>>(
  (ref) => ref.watch(favoritesRepositoryProvider).shops(),
);
