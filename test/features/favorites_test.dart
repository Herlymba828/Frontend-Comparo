import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/favorites/favorite_buttons.dart';
import 'package:frontend/features/favorites/favorites_repository.dart';
import 'package:frontend/features/favorites/favorites_screen.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';

import '../support/fake_api.dart';

Map<String, Object?> _favorite() => {
  'product': productJson(7, 'Riz démo', price: '900.00'),
  'change_percent': '-10.0',
  'trend': 'down',
};

FakeApi _api({List<int> followedProducts = const [7]}) => FakeApi((request) {
  return switch (request.path) {
    'api/favorites/' => ok({
      'product_ids': followedProducts,
      'merchant_ids': [3],
    }),
    'api/favorites/products/' when request.method == 'GET' => ok({
      'count': 1,
      'next': null,
      'results': [_favorite()],
    }),
    'api/favorites/merchants/' when request.method == 'GET' => ok({
      'count': 1,
      'next': null,
      'results': [
        {
          'merchant': {
            'id': 3,
            'name': 'Épicerie démo',
            'logo_url': '',
            'is_verified': true,
          },
          'offer_count': 2,
        },
      ],
    }),
    _ => (status: 204, body: null),
  };
});

Future<void> _pump(
  WidgetTester tester,
  FakeApi api,
  Widget home, {
  bool signedIn = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          signedIn ? SignedInSession.new : VisitorSession.new,
        ),
        jsonApiProvider.overrideWithValue(api.jsonApi),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the API answers', () {
    test('a followed product comes with the price move since it was added', () {
      final favorite = FavoriteProduct.fromJson(_favorite());

      expect(favorite.product.name, 'Riz démo');
      expect(favorite.changePercent, '-10.0');
      expect(favorite.trend, PriceTrend.down);
    });

    test('a favourite without its product is refused', () {
      expect(
        () => FavoriteProduct.fromJson({'trend': 'up'}),
        throwsFormatException,
      );
    });

    test('an unknown trend reads as no trend', () {
      final favorite = FavoriteProduct.fromJson({
        ..._favorite(),
        'trend': 'sideways',
      });

      expect(favorite.trend, isNull);
    });

    test('the repository follows and unfollows by id', () async {
      final api = _api();
      final repository = FavoritesRepository(api.jsonApi);

      await repository.followProduct(7);
      await repository.unfollowProduct(7);
      await repository.followShop(3);
      await repository.unfollowShop(3);

      expect(api.sent('POST', 'api/favorites/products/').single.data, {
        'product_id': 7,
      });
      expect(api.sent('DELETE', 'api/favorites/products/7/'), hasLength(1));
      expect(api.sent('POST', 'api/favorites/merchants/').single.data, {
        'merchant_id': 3,
      });
      expect(api.sent('DELETE', 'api/favorites/merchants/3/'), hasLength(1));
    });
  });

  group('formatTrendPercent', () {
    test('writes the move with its sign and a thin space before the %', () {
      expect(
        formatTrendPercent('-10.0', PriceTrend.down),
        '−10 % depuis l’ajout',
      );
      expect(formatTrendPercent('4.5', PriceTrend.up), '+4,5 % depuis l’ajout');
    });

    test('says "Stable", or nothing when the API did not say', () {
      expect(formatTrendPercent('0.4', PriceTrend.stable), 'Stable');
      expect(formatTrendPercent(null, null), isNull);
      expect(formatTrendPercent(null, PriceTrend.down), isNull);
    });
  });

  group('Mes favoris', () {
    testWidgets('lists the followed products with their price and trend', (
      tester,
    ) async {
      await _pump(tester, _api(), const FavoritesScreen());

      expect(find.text('Riz démo'), findsOneWidget);
      expect(find.text('dès 900 FCFA'), findsOneWidget);
      expect(find.text('−10 % depuis l’ajout'), findsOneWidget);
    });

    testWidgets('removing a product asks the API and says so', (tester) async {
      final api = _api();
      await _pump(tester, api, const FavoritesScreen());

      await tester.tap(find.byTooltip('Retirer des favoris'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/favorites/products/7/'), hasLength(1));
      expect(find.text('Retiré de vos favoris.'), findsOneWidget);
    });

    testWidgets('the shops tab lists the followed shops', (tester) async {
      await _pump(tester, _api(), const FavoritesScreen());

      await tester.tap(find.text('Commerces'));
      await tester.pumpAndSettle();

      expect(find.text('Épicerie démo'), findsOneWidget);
      expect(find.textContaining('2 offres'), findsOneWidget);
      expect(find.textContaining('boutique vérifiée'), findsOneWidget);
    });

    testWidgets('a visitor is asked to sign in', (tester) async {
      await _pump(tester, _api(), const FavoritesScreen(), signedIn: false);

      expect(
        find.text('Connectez-vous pour retrouver vos favoris.'),
        findsOneWidget,
      );
    });
  });

  group('the heart of a product', () {
    testWidgets('is filled for a followed product and unfollows it', (
      tester,
    ) async {
      final api = _api();
      await _pump(
        tester,
        api,
        const Scaffold(body: FavoriteProductButton(productId: 7)),
      );

      await tester.tap(find.byTooltip('Retirer des favoris'));
      await tester.pumpAndSettle();

      expect(api.sent('DELETE', 'api/favorites/products/7/'), hasLength(1));
    });

    testWidgets('follows a product that is not followed yet', (tester) async {
      final api = _api(followedProducts: const []);
      await _pump(
        tester,
        api,
        const Scaffold(body: FavoriteProductButton(productId: 9)),
      );

      await tester.tap(find.byTooltip('Ajouter aux favoris'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', 'api/favorites/products/').single.data, {
        'product_id': 9,
      });
      expect(find.text('Ajouté à vos favoris.'), findsOneWidget);
    });
  });
}
