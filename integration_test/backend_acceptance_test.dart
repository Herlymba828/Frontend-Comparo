// Recette P6.3 contre le backend Docker local alimenté par
// `python manage.py seed_frontend_demo_data` (DEBUG uniquement).
//
//   flutter test integration_test/backend_acceptance_test.dart -d emulator-5554 \
//     --dart-define=API_BASE_URL=http://10.0.2.2:8010
//
// Mesure aussi la latence de recherche backend (10 exécutions, p50/p95).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/core/widgets/market_widgets.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/storage/cache_storage.dart';
import 'package:frontend/core/storage/offline_cache.dart';
import 'package:frontend/features/catalog/data/catalog_providers.dart';
import 'package:frontend/features/catalog/data/catalog_repository.dart';
import 'package:frontend/features/catalog/models/catalog_search_request.dart';
import 'package:integration_test/integration_test.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'anonymous search, product sheet and comparison on the real API',
    (tester) async {
      AppRouter.router.go('/');
      await tester.pumpWidget(const ProviderScope(child: ComparateurPrixApp()));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Prix du jour'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).first, 'riz');
      await tester.tap(find.byTooltip('Rechercher').first);
      await _settleNetwork(tester);

      expect(find.text('Riz parfumé démo — 500 g'), findsOneWidget);
      expect(find.text('Riz complet démo — 1 kg'), findsOneWidget);

      await tester.tap(find.text('Riz parfumé démo — 500 g'));
      await _settleNetwork(tester);

      expect(find.text('Comparaison d’offres'), findsOneWidget);
      expect(find.text('Marché démo'), findsWidgets);
      expect(find.text('950,00 XAF'), findsOneWidget);
      // Offres vérifiées manuellement et récentes : le tampon revient au plus
      // bas prix au kilo, 1 800 XAF/kg chez Épicerie démo, contre 1 900 XAF/kg
      // (950 XAF les 500 g) chez Marché démo.
      expect(find.byType(BestPriceSeal), findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.byType(BestPriceSeal),
                matching: find.byType(Stack),
              )
              .first,
          matching: find.text('Épicerie démo'),
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Disponibilité chez les marchands'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _settleNetwork(tester);
      expect(find.text('Disponible'), findsWidgets);
    },
    skip: _apiBaseUrl.isEmpty,
  );

  testWidgets('backend search latency (10 runs)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ComparateurPrixApp()));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final repository = container.read(catalogRepositoryProvider);
    final durations = <int>[];
    for (var run = 0; run < 10; run++) {
      final stopwatch = Stopwatch()..start();
      await tester.runAsync(
        () => repository.searchProducts(
          CatalogSearchRequest(query: 'riz', page: 1, pageSize: 20),
        ),
      );
      durations.add(stopwatch.elapsedMilliseconds);
    }
    durations.sort();
    final report = {
      'search_ms_p50': durations[4],
      'search_ms_p95': durations[9],
      'search_ms_runs': durations,
    };
    binding.reportData = report;
    // ignore: avoid_print
    print('BACKEND_SEARCH_LATENCY $report');
    expect(durations[9], lessThanOrEqualTo(2000));
  }, skip: _apiBaseUrl.isEmpty);

  _deviceCacheAndPagination();
}

/// Filtres, pagination, panne serveur et frontière d'expiration du cache,
/// avec l'API réelle et le cache SQLite de l'appareil.
void _deviceCacheAndPagination() {
  testWidgets(
    'filters, pagination, server outage and cache expiry on the device',
    (tester) async {
      await tester.runAsync(() async {
        final storage = createCacheStorage();
        var now = DateTime.now().toUtc();
        final cache = OfflineCache(storage: storage, now: () => now);
        await cache.clear();
        CatalogRepository repository(String baseUrl) => CatalogRepository(
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 3),
            ),
          ),
          cache: cache,
          hasNetwork: () async => true,
        );
        final online = repository('$_apiBaseUrl/');

        const firstPage = CatalogSearchRequest(
          query: 'riz',
          pageSize: 2,
          ordering: 'name',
        );
        final page1 = await online.searchProducts(firstPage);
        final page2 = await online.searchProducts(
          const CatalogSearchRequest(
            query: 'riz',
            pageSize: 2,
            ordering: 'name',
            page: 2,
          ),
        );
        expect(page1.value.count, 3);
        expect(page1.value.results, hasLength(2));
        expect(page1.value.next, isNotNull);
        expect(page2.value.results, hasLength(1));
        final ids = {
          ...page1.value.results.map((product) => product.id),
          ...page2.value.results.map((product) => product.id),
        };
        expect(ids, hasLength(3), reason: 'no duplicate across pages');

        final available = await online.searchProducts(
          const CatalogSearchRequest(query: 'riz', available: true),
        );
        // Le jeu de recette contient exactement un produit disponible ; une
        // liste vide ne doit pas valider le filtre.
        expect(available.value.results.map((product) => product.name), [
          'Riz parfumé démo — 500 g',
        ]);
        expect(available.value.results.single.availability, 'available');

        // Serveur injoignable : port fermé sur l'hôte.
        final outage = repository('http://10.0.2.2:9/');
        final cached = await outage.searchProducts(firstPage);
        expect(cached.isFromCache, isTrue);
        expect(cached.isExpired, isFalse);
        expect(cached.value.results, hasLength(2));

        now = now.add(const Duration(days: 7));
        final expired = await outage.searchProducts(firstPage);
        expect(expired.isFromCache, isTrue);
        expect(expired.isExpired, isTrue);

        await cache.clear();
        await expectLater(
          outage.searchProducts(firstPage),
          throwsA(isA<ApiException>()),
        );
      });
    },
    skip: _apiBaseUrl.isEmpty,
  );
}

/// Les appels réels se résolvent hors de l'horloge simulée du test.
Future<void> _settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}
