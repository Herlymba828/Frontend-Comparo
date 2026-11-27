import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/formatters/price_formatter.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/stores/stores_repository.dart';
import 'package:frontend/features/stores/stores_screen.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_api.dart';

const _storesPath = 'api/comparison/products/5/stores/';

Map<String, Object?> _store({
  int id = 1,
  String merchant = 'Marché démo',
  String location = 'Boutique Centre',
  String street = 'Avenue Léon Mba',
  String city = 'Libreville',
  String phone = '',
  Object? latitude = '0.390000',
  Object? longitude = '9.454000',
  Object? distance = 0.22,
  String amount = '950.00',
  String? unitPrice,
  bool promo = false,
}) => {
  'offer_id': id,
  'product_name': 'Riz',
  'merchant_name': merchant,
  'location_name': location,
  'street': street,
  'city': city,
  'phone': phone,
  'latitude': latitude,
  'longitude': longitude,
  'distance_km': distance,
  'amount': amount,
  'currency': 'XAF',
  'quantity': '500',
  'unit_symbol': 'g',
  'unit_price': unitPrice,
  'unit_price_unit': unitPrice == null ? null : 'kg',
  'availability': 'available',
  'freshness': 'recent',
  'is_promotion': promo,
};

Map<String, Object?> _page(List<Map<String, Object?>> items) => {
  'count': items.length,
  'next': null,
  'results': items,
};

/// A position service that answers from the test, and counts its calls.
class _Positions extends PositionService {
  _Positions(this._answer);

  final Future<UserPosition> Function() _answer;
  int calls = 0;

  @override
  Future<UserPosition> locate() {
    calls++;
    return _answer();
  }
}

const _libreville = UserPosition.found(0.39, 9.45, accuracyM: 12);

/// Records the links the app tries to open and answers whether one opened.
List<String> _recordLaunches(WidgetTester tester, {bool opens = true}) {
  final launched = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (call) async {
      final arguments = call.arguments;
      if (call.method == 'launch' && arguments is Map) {
        launched.add(arguments['url'] as String);
      }
      return opens;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    ),
  );
  return launched;
}

class _Opened {
  _Opened(this.api, this.positions);

  final FakeApi api;
  final _Positions positions;

  RequestOptions get lastQuery => api.sent('GET', _storesPath).last;
}

Future<_Opened> _open(
  WidgetTester tester, {
  Future<UserPosition> Function()? position,
  List<Map<String, Object?>> stores = const [],
  String? failure,
  String? productName = 'Riz parfumé',
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeApi(
    (request) => failure != null
        ? (
            status: 500,
            body: {
              'error': {'code': 'server_error', 'detail': failure},
            },
          )
        : ok(_page(stores)),
  );
  final positions = _Positions(position ?? () async => _libreville);
  await tester.pumpWidget(
    ProviderScope(
      // No automatic retry: a second attempt must come from the user.
      retry: (retryCount, error) => null,
      overrides: [
        jsonApiProvider.overrideWithValue(api.jsonApi),
        positionServiceProvider.overrideWithValue(positions),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: StoresScreen(productId: 5, productName: productName),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Opened(api, positions);
}

void main() {
  group('the nearby-stores button', () {
    Future<void> openWith(WidgetTester tester, {required Widget button}) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(body: Center(child: button)),
          ),
          GoRoute(
            path: '/product/:id/stores',
            builder: (context, state) => Scaffold(
              body: Text(
                'Magasins ${state.pathParameters['id']} '
                '${state.uri.queryParameters['name'] ?? '(sans nom)'}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens the stores of the product with its name', (
      tester,
    ) async {
      await openWith(
        tester,
        button: const NearbyStoresButton(productId: 5, productName: 'Riz & Co'),
      );

      await tester.tap(
        find.byTooltip('Magasins proches qui vendent ce produit'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Magasins 5 Riz & Co'), findsOneWidget);
    });

    testWidgets('opens them without a name too', (tester) async {
      await openWith(tester, button: const NearbyStoresButton(productId: 5));

      await tester.tap(
        find.byTooltip('Magasins proches qui vendent ce produit'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Magasins 5 (sans nom)'), findsOneWidget);
    });

    testWidgets('has a round version for product cards', (tester) async {
      await openWith(
        tester,
        button: const NearbyStoresButton(productId: 5, compact: true),
      );

      final round = find.byWidgetPredicate(
        (widget) => widget is Material && widget.shape is CircleBorder,
      );
      expect(round, findsOneWidget);
      await tester.tap(
        find.byTooltip('Magasins proches qui vendent ce produit'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Magasins 5'), findsOneWidget);
    });
  });

  group('the position', () {
    testWidgets('is awaited before the stores are asked for', (tester) async {
      final pending = Completer<UserPosition>();
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeApi((request) => ok(_page([_store()])));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jsonApiProvider.overrideWithValue(api.jsonApi),
            positionServiceProvider.overrideWithValue(
              _Positions(() => pending.future),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const StoresScreen(productId: 5),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Recherche de votre position…'), findsOneWidget);
      expect(api.sent('GET', _storesPath), isEmpty);
      expect(find.text('Magasins'), findsOneWidget);

      pending.complete(_libreville);
      await tester.pumpAndSettle();
      expect(find.text('Marché démo'), findsOneWidget);
    });

    testWidgets('a known one sorts by distance and is sent with the query', (
      tester,
    ) async {
      final opened = await _open(tester, stores: [_store()]);

      final query = opened.lastQuery.queryParameters;
      expect(query['lat'], '0.390000');
      expect(query['lon'], '9.450000');
      expect(query['ordering'], 'distance');
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.text('LE PLUS PROCHE'), findsOneWidget);
      expect(find.text('LE MOINS CHER'), findsNothing);
    });

    testWidgets('a missing one explains why and sorts by price', (
      tester,
    ) async {
      final opened = await _open(
        tester,
        position: () async =>
            const UserPosition.missing('La localisation est désactivée.'),
        stores: [_store()],
      );

      expect(find.text('La localisation est désactivée.'), findsOneWidget);
      expect(opened.lastQuery.queryParameters['ordering'], 'price');
      expect(opened.lastQuery.queryParameters.containsKey('lat'), isFalse);
      expect(find.text('LE MOINS CHER'), findsOneWidget);
      final nearest = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(
        nearest.segments.firstWhere((s) => s.value == 'distance').enabled,
        isFalse,
      );
    });

    testWidgets('a failing lookup falls back to price too', (tester) async {
      await _open(
        tester,
        position: () async => throw Exception('GPS en panne'),
        stores: [_store()],
      );

      expect(
        find.text('Position introuvable : magasins triés par prix.'),
        findsOneWidget,
      );
      expect(find.text('LE MOINS CHER'), findsOneWidget);
    });

    testWidgets('can be asked for again from the banner', (tester) async {
      final opened = await _open(
        tester,
        position: () async => const UserPosition.missing('Position refusée.'),
        stores: [_store()],
      );
      expect(opened.positions.calls, 1);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(opened.positions.calls, 2);
    });

    testWidgets('can be refreshed from the app bar', (tester) async {
      final opened = await _open(tester, stores: [_store()]);

      await tester.tap(find.byTooltip('Actualiser ma position'));
      await tester.pumpAndSettle();

      expect(opened.positions.calls, 2);
    });
  });

  group('the list', () {
    testWidgets('is titled with the product, or plainly', (tester) async {
      await _open(tester, stores: [_store()]);
      expect(find.text('Riz parfumé'), findsOneWidget);

      await _open(tester, stores: [_store()], productName: null);
      expect(find.text('Magasins'), findsOneWidget);
    });

    testWidgets('can be switched to the cheapest first', (tester) async {
      final opened = await _open(
        tester,
        stores: [
          _store(),
          _store(id: 2, merchant: 'Chez Awa'),
        ],
      );

      await tester.tap(find.text('Moins chers'));
      await tester.pumpAndSettle();

      expect(opened.lastQuery.queryParameters['ordering'], 'price');
      expect(find.text('LE MOINS CHER'), findsOneWidget);
      expect(find.text('LE PLUS PROCHE'), findsNothing);
    });

    testWidgets('says when no store sells the product', (tester) async {
      await _open(tester);

      expect(
        find.text('Aucun magasin ne vend ce produit pour le moment.'),
        findsOneWidget,
      );
    });

    testWidgets('shows why the stores could not be loaded', (tester) async {
      final opened = await _open(tester, failure: 'Service indisponible.');

      expect(find.text('Service indisponible.'), findsOneWidget);
      final before = opened.api.sent('GET', _storesPath).length;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(opened.api.sent('GET', _storesPath).length, greaterThan(before));
    });

    testWidgets('can be pulled to refresh', (tester) async {
      final opened = await _open(tester, stores: [_store()]);
      final before = opened.api.sent('GET', _storesPath).length;

      await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(opened.api.sent('GET', _storesPath).length, greaterThan(before));
    });
  });

  group('a store card', () {
    testWidgets('gives the shop, its address, price and unit price', (
      tester,
    ) async {
      await _open(tester, stores: [_store(unitPrice: '1900.00', promo: true)]);

      expect(find.text('Marché démo'), findsOneWidget);
      expect(find.text('Boutique Centre'), findsOneWidget);
      expect(find.text('Avenue Léon Mba, Libreville'), findsOneWidget);
      expect(find.text(formatPrice('950.00', 'XAF')), findsOneWidget);
      expect(find.text('PROMO'), findsOneWidget);
      expect(
        find.text('${formatUnitPrice('1900.00', 'XAF')} / kg'),
        findsOneWidget,
      );
    });

    testWidgets('writes distances in metres, then in kilometres', (
      tester,
    ) async {
      await _open(
        tester,
        stores: [
          _store(distance: 0.22),
          _store(id: 2, distance: 1.5),
          _store(id: 3, distance: null),
        ],
      );

      expect(find.text('220 m'), findsOneWidget);
      expect(find.text('1,5 km'), findsOneWidget);
      expect(find.text('Distance inconnue'), findsOneWidget);
    });

    testWidgets('calls the shop when it has a phone', (tester) async {
      final launched = _recordLaunches(tester);
      await _open(tester, stores: [_store(phone: '+24106111111')]);

      await tester.tap(find.text('Appeler'));
      await tester.pumpAndSettle();

      expect(launched, ['tel:+24106111111']);
    });

    testWidgets('gives directions to its coordinates', (tester) async {
      final launched = _recordLaunches(tester);
      await _open(tester, stores: [_store()]);

      await tester.tap(find.text('Itinéraire'));
      await tester.pumpAndSettle();

      expect(
        launched.single,
        'https://www.google.com/maps/dir/?api=1&destination=0.39%2C9.454',
      );
    });

    testWidgets('gives directions to the address without coordinates', (
      tester,
    ) async {
      final launched = _recordLaunches(tester);
      await _open(tester, stores: [_store(latitude: null, longitude: null)]);

      await tester.tap(find.text('Itinéraire'));
      await tester.pumpAndSettle();

      expect(launched.single, contains('destination=Boutique+Centre'));
    });

    testWidgets('offers neither call nor directions without the data', (
      tester,
    ) async {
      await _open(
        tester,
        stores: [_store(latitude: null, longitude: null, street: '', city: '')],
      );

      expect(find.text('Appeler'), findsNothing);
      expect(find.text('Itinéraire'), findsNothing);
    });

    testWidgets('says so when nothing can open the link', (tester) async {
      _recordLaunches(tester, opens: false);
      await _open(tester, stores: [_store(phone: '+24106111111')]);

      await tester.tap(find.text('Appeler'));
      await tester.pumpAndSettle();

      expect(
        find.text('Aucune application ne peut ouvrir ce lien.'),
        findsOneWidget,
      );
    });
  });

  group('the device position', () {
    // The plugin is absent in tests: every call fails, as on a device
    // without location services.
    test('falls back to a message when nothing can be read', () async {
      final position = await locateUser();

      expect(position.isKnown, isFalse);
      expect(
        position.problem,
        'Position introuvable pour le moment : magasins triés par prix.',
      );
    });

    test('is not granted by default', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      expect(await const PositionService().isGranted(), isFalse);
    });

    test('a found position knows its accuracy', () {
      const position = UserPosition.found(0.4, 9.4, accuracyM: 25);

      expect(position.isKnown, isTrue);
      expect(position.accuracyM, 25);
      expect(position.problem, isNull);
    });

    test('a refusal is remembered as such', () {
      const position = UserPosition.missing('Refusée.', isDenied: true);

      expect(position.isKnown, isFalse);
      expect(position.isDenied, isTrue);
    });
  });
}
