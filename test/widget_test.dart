// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/features/catalog/data/catalog_providers.dart';
import 'package:frontend/features/catalog/data/catalog_repository.dart';
import 'package:frontend/features/catalog/models/catalog_product.dart';
import 'package:frontend/features/catalog/models/catalog_product_page.dart';
import 'package:frontend/features/catalog/models/catalog_search_request.dart';
import 'package:frontend/features/comparison/models/comparison_offer.dart';
import 'package:frontend/features/comparison/models/comparison_offer_page.dart';
import 'package:frontend/features/alerts/data/alert_repository.dart';
import 'package:frontend/features/availability/models/merchant_availability.dart';
import 'package:frontend/features/alerts/models/price_alert.dart';
import 'package:frontend/features/identity/data/auth_repository.dart';
import 'package:frontend/features/identity/data/auth_token_storage.dart';
import 'package:frontend/features/identity/models/auth_user.dart';
import 'package:frontend/features/product/product_screen.dart';
import 'package:frontend/core/storage/repository_result.dart';
import 'package:frontend/core/widgets/cache_status_banner.dart';
import 'package:frontend/features/search/search_screen.dart';

void main() {
  testWidgets('app starts and shows home screen title', (tester) async {
    AppRouter.router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
        ],
        child: const ComparateurPrixApp(),
      ),
    );

    expect(find.text('Comparateur Prix'), findsOneWidget);
    expect(find.text('Prix du jour'), findsOneWidget);
    expect(find.text('Explorer par catégorie'), findsOneWidget);
  });

  testWidgets('home displays fictional products returned by the catalog', (
    tester,
  ) async {
    final repository = _HomeFixtureCatalogRepository();
    AppRouter.router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
        child: const ComparateurPrixApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Produit fictif du catalogue'), findsOneWidget);
    expect(find.text('1\u202f234,50 XAF'), findsOneWidget);
    expect(
      repository.requestedSearches.any(
        (request) => request.ordering == '-created_at' && request.pageSize == 4,
      ),
      isTrue,
    );
  });

  testWidgets('home search button submits the entered query', (tester) async {
    final repository = _HomeFixtureCatalogRepository();
    AppRouter.router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
        child: const ComparateurPrixApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, '  lait  ');
    await tester.tap(find.byTooltip('Rechercher').first);
    await tester.pumpAndSettle();

    expect(find.text('Recherche de produit'), findsOneWidget);
    expect(
      repository.requestedSearches.any((request) => request.query == 'lait'),
      isTrue,
    );
  });

  testWidgets('home navigation opens product search', (tester) async {
    AppRouter.router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(
            _HomeFixtureCatalogRepository(),
          ),
        ],
        child: const ComparateurPrixApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recherche'));
    await tester.pumpAndSettle();

    expect(find.text('Recherche de produit'), findsOneWidget);
    expect(find.text('Produit'), findsOneWidget);
  });

  testWidgets('home category opens search prefiltered to that category', (
    tester,
  ) async {
    final repository = _HomeFixtureCatalogRepository();
    AppRouter.router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
        child: const ComparateurPrixApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Épicerie fictive'));
    await tester.tap(find.text('Épicerie fictive'));
    await tester.pumpAndSettle();

    expect(find.text('Recherche de produit'), findsOneWidget);
    expect(find.text('Produit fictif du catalogue'), findsOneWidget);
    expect(
      repository.requestedSearches.any(
        (request) => request.category == 'epicerie-fictive',
      ),
      isTrue,
    );
  });

  testWidgets('search displays products returned by the catalog repository', (
    tester,
  ) async {
    AppRouter.router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
        ],
        child: const ComparateurPrixApp(),
      ),
    );

    await tester.tap(find.text('Recherche'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'riz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Riz parfumé'), findsOneWidget);
    expect(find.text('1\u202f250,00 XAF'), findsOneWidget);
    await tester.tap(find.text('Riz parfumé'));
    await tester.pumpAndSettle();
    expect(find.text('Fiche produit'), findsOneWidget);
    expect(find.text('Comparaison d’offres'), findsOneWidget);
  });

  testWidgets('product screen renders product details and comparison offers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              _FakeCatalogRepository(),
            ),
          ],
          child: const ProductScreen(productId: '15'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Riz parfumé'), findsOneWidget);
    expect(find.text('Comparaison d’offres'), findsOneWidget);
    expect(find.text('Supermarché local'), findsOneWidget);
    expect(find.text('1\u202f250,00 XAF'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Source : Supermarché local'), findsOneWidget);
    expect(find.textContaining('Fraîcheur : Récente'), findsOneWidget);
    expect(find.textContaining('Vérification du prix : Vérifié'), findsNothing);
    expect(find.textContaining('Prix : Vérifié'), findsOneWidget);
    expect(find.textContaining('Observé : 05/06/2026'), findsOneWidget);
    expect(find.text('Prix comparés en XAF / kg'), findsOneWidget);
    expect(find.text('Prix comparés en EUR / l'), findsOneWidget);
    expect(find.textContaining('Équivalence vérifiée'), findsOneWidget);
    expect(find.textContaining('Source : Source inconnue'), findsOneWidget);
    expect(find.textContaining('Observé : Date inconnue'), findsOneWidget);
    expect(find.textContaining('Disponibilité : Inconnue'), findsOneWidget);
    expect(find.textContaining('Fraîcheur : Ancienne'), findsOneWidget);
  });

  testWidgets('product price alert signs in and creates an alert', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final alertRepository = _FakeAlertRepository();
    AppRouter.router.go('/product/15');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
          authRepositoryProvider.overrideWithValue(authRepository),
          alertRepositoryProvider.overrideWithValue(alertRepository),
        ],
        child: const ComparateurPrixApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suivre le prix'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'client@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Suivre Riz parfumé'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '1200,50');
    await tester.tap(find.text('Créer l’alerte'));
    await tester.pumpAndSettle();

    expect(alertRepository.createdProductId, 15);
    expect(alertRepository.createdTriggerType, 'price_drop');
    expect(alertRepository.createdThresholdAmount, '1200.50');
    expect(find.text('Votre alerte de prix est créée.'), findsOneWidget);
  });

  testWidgets('product screen never invents a currency when it is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              _FakeCatalogRepository(includeCurrency: false),
            ),
          ],
          child: const ProductScreen(productId: '15'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1\u202f250,00 — devise non renseignée'), findsOneWidget);
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('product screen reports a missing price without a currency', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              _FakeCatalogRepository(includePrice: false),
            ),
          ],
          child: const ProductScreen(productId: '15'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prix non renseigné'), findsOneWidget);
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('cached expired results explain cache age separately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CacheStatusBanner(
            result: RepositoryResult<Object?>(
              value: null,
              cachedAtUtc: DateTime(2026, 6, 5, 9, 7).toUtc(),
              isExpired: true,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Cache expiré'), findsOneWidget);
    expect(find.textContaining('05/06/2026'), findsOneWidget);
  });

  testWidgets('search can navigate forward from its first page', (
    tester,
  ) async {
    final repository = _PaginatedCatalogRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
          child: const SearchScreen(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'riz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Page 1 sur 2'), findsOneWidget);
    expect(find.text('Riz parfumé'), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [1, 2]);
    expect(find.text('Page 2 sur 2'), findsOneWidget);
    expect(find.text('Riz complet'), findsOneWidget);
  });

  testWidgets('search filters fit on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              _FakeCatalogRepository(),
            ),
          ],
          child: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catégorie'), findsOneWidget);
    expect(find.text('Trier par'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers can navigate to their next page', (tester) async {
    final repository = _PaginatedOfferRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
          child: const ProductScreen(productId: '15'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offre page 1'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [1, 2]);
    expect(find.text('Offre page 2'), findsOneWidget);
  });
}

class _HomeFixtureCatalogRepository extends _FakeCatalogRepository {
  final requestedSearches = <CatalogSearchRequest>[];

  @override
  Future<List<CatalogCategory>> getCategoryTree({
    CancelToken? cancelToken,
  }) async => const [
    CatalogCategory(
      id: 901,
      name: 'Épicerie fictive',
      slug: 'epicerie-fictive',
    ),
  ];

  @override
  Future<RepositoryResult<CatalogProductPage>> searchProducts(
    dynamic request, {
    CancelToken? cancelToken,
  }) async {
    requestedSearches.add(request as CatalogSearchRequest);
    return RepositoryResult(
      value: CatalogProductPage(
        count: 1,
        results: const [
          CatalogProduct(
            id: 901,
            name: 'Produit fictif du catalogue',
            slug: 'produit-fictif-catalogue',
            availability: 'available',
            isActive: true,
            isVerified: false,
            priceSnapshot: '1234.50',
            priceSnapshotCurrency: 'XAF',
          ),
        ],
      ),
    );
  }
}

class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository({
    this.includeCurrency = true,
    this.includePrice = true,
  }) : super(Dio());

  final bool includeCurrency;
  final bool includePrice;

  @override
  Future<List<CatalogCategory>> getCategoryTree({
    CancelToken? cancelToken,
  }) async => const [];

  @override
  Future<RepositoryResult<CatalogProductPage>> searchProducts(
    dynamic request, {
    CancelToken? cancelToken,
  }) async {
    return RepositoryResult(
      value: CatalogProductPage(
        count: 1,
        results: [
          CatalogProduct(
            id: 15,
            name: 'Riz parfumé',
            slug: 'riz-parfume',
            availability: 'unknown',
            isActive: true,
            isVerified: true,
            priceSnapshot: includePrice ? '1250.00' : null,
            priceSnapshotCurrency: includeCurrency ? 'XAF' : null,
          ),
        ],
      ),
    );
  }

  @override
  Future<RepositoryResult<CatalogProduct>> getProduct(
    int productId, {
    CancelToken? cancelToken,
  }) async {
    expect(productId, 15);
    return RepositoryResult(
      value: CatalogProduct(
        id: 15,
        name: 'Riz parfumé',
        slug: 'riz-parfume',
        availability: 'available',
        isActive: true,
        isVerified: true,
        priceSnapshot: includePrice ? '1250.00' : null,
        priceSnapshotCurrency: includeCurrency ? 'XAF' : null,
        description: 'Riz parfumé pour les repas du quotidien.',
      ),
    );
  }

  @override
  Future<RepositoryResult<ComparisonOfferPage>> getComparisonOffers(
    int productId, {
    int page = 1,
    int pageSize = 20,
    String? location,
    CancelToken? cancelToken,
  }) async {
    expect(productId, 15);
    return RepositoryResult(
      value: ComparisonOfferPage(
        count: 2,
        results: [
          ComparisonOffer(
            id: 77,
            product: 15,
            productName: 'Riz parfumé',
            amount: '1250.00',
            currency: 'XAF',
            quantity: '1.0000',
            merchantName: 'Supermarché local',
            unitSymbol: 'kg',
            unitCode: 'kg',
            isActive: true,
            isPromotion: false,
            isCurrentlyValid: true,
            comparisonReasons: ['same_product'],
            availability: 'available',
            freshness: 'recent',
            verificationLevel: 'manual',
            observedAt: DateTime(2026, 6, 5, 11, 12),
            sourceLabel: 'Supermarché local',
            comparisonGroup: ComparisonGroup(currency: 'XAF', unitCode: 'kg'),
            normalizedUnitPrice: '1250.000000',
            normalizedUnit: CatalogUnit(
              id: 1,
              code: 'kg',
              symbol: 'kg',
              unitType: 'mass',
            ),
          ),
          ComparisonOffer(
            id: 78,
            product: 15,
            productName: 'Riz parfumé',
            amount: '9.50',
            currency: 'EUR',
            quantity: '1.0000',
            merchantName: 'Marché européen',
            unitCode: 'l',
            isActive: true,
            isPromotion: false,
            isCurrentlyValid: true,
            comparisonReasons: ['strict_equivalence'],
            availability: 'unknown',
            freshness: 'old',
            comparisonGroup: ComparisonGroup(currency: 'EUR', unitCode: 'l'),
          ),
        ],
      ),
    );
  }

  @override
  Future<RepositoryResult<MerchantAvailabilityPage>> getProductAvailability(
    int productId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return RepositoryResult(
      value: MerchantAvailabilityPage(
        count: 1,
        results: [
          MerchantAvailability(
            id: 5,
            product: productId,
            merchantName: 'Supermarché local',
            status: 'limited',
            isAvailable: true,
            quantityAvailable: '3.000',
            observedAt: DateTime(2026, 6, 4),
          ),
        ],
      ),
    );
  }
}

class _PaginatedCatalogRepository extends _FakeCatalogRepository {
  final requestedPages = <int>[];

  @override
  Future<RepositoryResult<CatalogProductPage>> searchProducts(
    dynamic request, {
    CancelToken? cancelToken,
  }) async {
    final resolved = request as CatalogSearchRequest;
    requestedPages.add(resolved.page);
    final isFirstPage = resolved.page == 1;
    return RepositoryResult(
      value: CatalogProductPage(
        count: 21,
        next: isFirstPage ? 'https://api.example.com?page=2' : null,
        previous: isFirstPage ? null : 'https://api.example.com?page=1',
        results: [
          CatalogProduct(
            id: isFirstPage ? 15 : 16,
            name: isFirstPage ? 'Riz parfumé' : 'Riz complet',
            slug: isFirstPage ? 'riz-parfume' : 'riz-complet',
            availability: 'available',
            isActive: true,
            isVerified: true,
            priceSnapshot: '1250.00',
            priceSnapshotCurrency: 'XAF',
          ),
          if (isFirstPage)
            const CatalogProduct(
              id: 15,
              name: 'Riz parfumé',
              slug: 'riz-parfume-duplicate',
              availability: 'available',
              isActive: true,
              isVerified: true,
            ),
        ],
      ),
    );
  }
}

class _PaginatedOfferRepository extends _FakeCatalogRepository {
  final requestedPages = <int>[];

  @override
  Future<RepositoryResult<ComparisonOfferPage>> getComparisonOffers(
    int productId, {
    int page = 1,
    int pageSize = 20,
    String? location,
    CancelToken? cancelToken,
  }) async {
    requestedPages.add(page);
    return RepositoryResult(
      value: ComparisonOfferPage(
        count: 21,
        next: page == 1 ? 'https://api.example.com?page=2' : null,
        previous: page == 1 ? null : 'https://api.example.com?page=1',
        results: [
          ComparisonOffer(
            id: 100 + page,
            product: productId,
            productName: 'Riz parfumé',
            amount: '1250.00',
            currency: 'XAF',
            quantity: '1.0000',
            merchantName: 'Offre page $page',
            unitCode: 'kg',
            isActive: true,
            isPromotion: false,
            isCurrentlyValid: true,
            comparisonReasons: const [],
            comparisonGroup: const ComparisonGroup(
              currency: 'XAF',
              unitCode: 'kg',
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Dio(), _TestTokenStorage());

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => const AuthUser(
    id: 1,
    email: 'client@example.com',
    displayName: 'Client',
    emailVerified: false,
  );
}

class _TestTokenStorage implements AuthTokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

class _FakeAlertRepository extends AlertRepository {
  _FakeAlertRepository() : super(Dio());

  int? createdProductId;
  String? createdTriggerType;
  String? createdThresholdAmount;

  @override
  Future<List<PriceAlert>> getAlerts() async => const [];

  @override
  Future<PriceAlert> createAlert({
    required int productId,
    required String triggerType,
    String? thresholdAmount,
    String thresholdCurrency = 'XAF',
    bool repeat = false,
  }) async {
    createdProductId = productId;
    createdTriggerType = triggerType;
    createdThresholdAmount = thresholdAmount;
    return PriceAlert(
      id: 1,
      productId: productId,
      productName: 'Riz parfumé',
      triggerType: triggerType,
      status: 'active',
      isActive: true,
      repeat: repeat,
      thresholdAmount: thresholdAmount,
      thresholdCurrency: thresholdCurrency,
    );
  }
}
