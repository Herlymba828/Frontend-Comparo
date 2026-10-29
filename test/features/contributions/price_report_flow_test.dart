import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/contributions/price_report_repository.dart';
import 'package:frontend/features/contributions/price_report_screen.dart';
import 'package:frontend/features/stores/stores_repository.dart';

const _central = ReportStore(
  id: 4,
  name: 'Étal central',
  merchantName: 'Marché Mont-Bouët',
  street: 'Avenue Bouët',
  city: 'Libreville',
  distanceM: 120,
);
const _annex = ReportStore(
  id: 5,
  name: 'Annexe nord',
  merchantName: 'Marché Mont-Bouët',
  street: 'Rue nord',
  city: 'Libreville',
  distanceM: 400,
);
const _rice = ProductSuggestion(7, 'Riz parfumé 1 kg');
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _FakePositions implements PositionService {
  _FakePositions({required this.granted, required this.position});

  final bool granted;
  final UserPosition position;
  int locateCalls = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<UserPosition> locate() async {
    locateCalls++;
    return position;
  }
}

const _unplaced = ReportStore(
  id: 6,
  name: 'Kiosque du rond-point',
  merchantName: 'Kiosque du rond-point',
  street: 'Rond-point',
  city: 'Libreville',
  hasCoordinates: false,
);

class _FakeReports implements PriceReportRepository {
  _FakeReports({
    this.nearby = const [_central],
    this.found = const [_central, _annex],
    this.proposal = const StoreProposalResult(
      status: 'pending',
      sightings: 3,
      required: 10,
    ),
    this.check = const PriceCheck(
      sampleSize: 4,
      isOutlier: false,
      medianUnitPrice: '1025.00',
      baseUnit: 'kg',
      typicalQuantity: '1',
      typicalUnit: 'kg',
    ),
  });

  final List<ReportStore> nearby;
  final List<ReportStore> found;
  final StoreProposalResult proposal;
  final PriceCheck check;
  Exception? submitError;
  Exception? proposalError;
  final drafts = <PriceReportDraft>[];
  final proposals = <String>[];
  final located = <int>[];

  @override
  Future<StoreProposalResult> proposeStore({
    required String name,
    required String city,
    required String street,
    required UserPosition position,
  }) async {
    proposals.add('$name|$city|$street');
    final error = proposalError;
    if (error != null) {
      throw error;
    }
    return proposal;
  }

  @override
  Future<StoreProposalResult> locateStore(
    int storeId,
    UserPosition position,
  ) async {
    located.add(storeId);
    return proposal;
  }

  @override
  Future<List<ReportStore>> nearbyStores(UserPosition position) async => nearby;

  @override
  Future<List<ReportStore>> searchStores(String text) async => found;

  @override
  Future<List<ProductSuggestion>> searchProducts(String text) async => [_rice];

  @override
  Future<List<UnitOption>> units() async => const [
    UnitOption(code: 'kg', name: 'Kilogramme', symbol: 'kg'),
    UnitOption(code: 'g', name: 'Gramme', symbol: 'g'),
  ];

  @override
  Future<PriceCheck> priceCheck({
    required int productId,
    String? price,
    String? quantity,
    String? unitCode,
  }) async => check;

  @override
  Future<int> submit(PriceReportDraft draft) async {
    drafts.add(draft);
    final error = submitError;
    if (error != null) {
      submitError = null;
      throw error;
    }
    return 99;
  }
}

class _NoPhotos implements PhotoPicker {
  @override
  Future<PhotoAttachment?> pick({required bool fromCamera}) async =>
      PhotoAttachment(bytes: _onePixelPng, filename: 'label.jpg');
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeReports reports,
  required _FakePositions positions,
  Size size = const Size(390, 1400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        priceReportRepositoryProvider.overrideWithValue(reports),
        positionServiceProvider.overrideWithValue(positions),
        photoPickerProvider.overrideWithValue(_NoPhotos()),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('fr', 'FR'),
          supportedLocales: const [Locale('fr', 'FR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(body: PriceReportForm()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _here = UserPosition.found(0.4162, 9.4673, accuracyM: 20);

Future<void> _fillRice(WidgetTester tester, String price) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Produit (nom complet, marque, format)'),
    'riz',
  );
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Riz parfumé 1 kg'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Prix affiché'),
    price,
  );
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Enregistrer le relevé'));
  await tester.tap(find.text('Enregistrer le relevé'));
  await tester.pumpAndSettle();
}

void main() {
  group('community stores', storeProposalTests);

  testWidgets('with the permission granted the closest store is found and '
      'a report takes a few taps', (tester) async {
    final reports = _FakeReports();
    final positions = _FakePositions(granted: true, position: _here);
    await _pump(tester, reports: reports, positions: positions);

    expect(find.text('Marché Mont-Bouët'), findsOneWidget);
    expect(find.textContaining('à 120 m de vous'), findsOneWidget);

    await _fillRice(tester, '1 500');
    expect(find.text('Prix habituel : environ 1 025 XAF / kg.'), findsOne);
    await _save(tester);

    final draft = reports.drafts.single;
    expect(draft.store.id, _central.id);
    expect(draft.locationMethod, LocationMethod.gps);
    expect(draft.position?.accuracyM, 20);
    expect(draft.productId, _rice.id);
    expect(draft.productName, 'Riz parfumé 1 kg');
    expect(draft.price, '1500');
    expect((draft.quantity, draft.unitCode), ('1', 'kg'));
    expect(draft.confirmOutlier, isFalse);
    expect(find.textContaining('Relevé enregistré'), findsOneWidget);
    // Ready for the next product in the same store.
    expect(find.text('Marché Mont-Bouët'), findsOneWidget);
    expect(find.text('Riz parfumé 1 kg'), findsNothing);
    final quantity = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Quantité'),
    );
    expect(quantity.controller?.text, '1');
    expect(find.widgetWithText(TextFormField, '1500'), findsNothing);
  });

  testWidgets('the position is never read before the user agrees; the store '
      'can be chosen by hand', (tester) async {
    final reports = _FakeReports();
    final positions = _FakePositions(granted: false, position: _here);
    await _pump(tester, reports: reports, positions: positions);

    expect(find.text('Utiliser ma position'), findsOneWidget);
    expect(find.text('Vos données et vos droits'), findsOneWidget);
    expect(positions.locateCalls, 0);

    await tester.tap(find.text('Choisir le magasin moi-même'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Rechercher le magasin'),
      'mont',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annexe nord · Rue nord, Libreville'));
    await tester.pumpAndSettle();

    await _fillRice(tester, '1500');
    await _save(tester);
    expect(positions.locateCalls, 0);
    expect(reports.drafts.single.locationMethod, LocationMethod.manual);
    expect(reports.drafts.single.position, isNull);
    expect(reports.drafts.single.store.id, _annex.id);
  });

  testWidgets('a refused permission falls back to the store search', (
    tester,
  ) async {
    final positions = _FakePositions(
      granted: false,
      position: const UserPosition.missing('Refusée', isDenied: true),
    );
    await _pump(tester, reports: _FakeReports(), positions: positions);

    await tester.tap(find.text('Utiliser ma position'));
    await tester.pumpAndSettle();
    expect(
      find.text('Localisation refusée : recherchez le magasin par son nom.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Rechercher le magasin'),
      findsOneWidget,
    );
  });

  testWidgets('several nearby stores are listed for the user to choose', (
    tester,
  ) async {
    final reports = _FakeReports(nearby: const [_central, _annex]);
    await _pump(
      tester,
      reports: reports,
      positions: _FakePositions(granted: true, position: _here),
    );
    expect(find.text('Magasins à moins de 500 m'), findsOneWidget);
    expect(find.text('400 m'), findsOneWidget);
    await tester.tap(find.text('120 m'));
    await tester.pumpAndSettle();
    expect(find.textContaining('à 120 m de vous'), findsOneWidget);
  });

  testWidgets('inputs are validated before anything is sent', (tester) async {
    final reports = _FakeReports();
    await _pump(
      tester,
      reports: reports,
      positions: _FakePositions(granted: true, position: _here),
    );

    await _save(tester);
    expect(find.text('Indiquez le nom du produit.'), findsOneWidget);
    expect(find.text('Indiquez le prix affiché.'), findsOneWidget);

    await _fillRice(tester, '1500,50');
    await _save(tester);
    expect(find.text('Le prix en XAF s’écrit sans centimes.'), findsOneWidget);
    expect(reports.drafts, isEmpty);
  });

  testWidgets('an unusual price is flagged and must be confirmed', (
    tester,
  ) async {
    final reports = _FakeReports(
      check: const PriceCheck(
        sampleSize: 4,
        isOutlier: true,
        medianUnitPrice: '1025.00',
        baseUnit: 'kg',
        typicalUnit: 'kg',
      ),
    );
    await _pump(
      tester,
      reports: reports,
      positions: _FakePositions(granted: true, position: _here),
    );
    await _fillRice(tester, '9000');
    expect(find.textContaining('Prix inhabituel'), findsOneWidget);

    await _save(tester);
    expect(find.text('Oui, c’est le bon prix'), findsOneWidget);
    await tester.tap(find.text('Oui, c’est le bon prix'));
    await tester.pumpAndSettle();
    expect(reports.drafts.single.confirmOutlier, isTrue);
  });

  testWidgets('a duplicate of the day is explained', (tester) async {
    final reports = _FakeReports()
      ..submitError = const DuplicateReportException(
        message: 'Ce produit a déjà été relevé dans ce magasin.',
        existingId: 3,
        isMine: false,
      );
    await _pump(
      tester,
      reports: reports,
      positions: _FakePositions(granted: true, position: _here),
    );
    await _fillRice(tester, '1500');
    await _save(tester);
    expect(find.text('Déjà relevé ces dernières 24 h'), findsOneWidget);
    expect(find.text('Voir les relevés à vérifier'), findsOneWidget);
  });

  testWidgets('a photo and a display error can be attached', (tester) async {
    final reports = _FakeReports();
    await _pump(
      tester,
      reports: reports,
      positions: _FakePositions(granted: true, position: _here),
    );
    await _fillRice(tester, '1500');
    await tester.ensureVisible(find.text('Photographier l’étiquette'));
    await tester.tap(find.text('Photographier l’étiquette'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Photo de l’étiquette jointe'), findsOne);
    await tester.tap(find.text('Signaler une erreur d’affichage'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Précisez (facultatif)'),
      'Étiquette périmée',
    );
    await _save(tester);
    final draft = reports.drafts.single;
    expect(draft.photo?.filename, 'label.jpg');
    expect(draft.displayError, isTrue);
    expect(draft.notes, 'Étiquette périmée');
  });

  for (final granted in [false, true]) {
    testWidgets('the form meets the tap target, label and contrast '
        'guidelines (permission granted: $granted)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        reports: _FakeReports(),
        positions: _FakePositions(granted: granted, position: _here),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  testWidgets('sections are announced as headings', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      reports: _FakeReports(),
      positions: _FakePositions(granted: true, position: _here),
    );
    for (final title in ['1. Magasin', '2. Produit et prix']) {
      expect(
        tester.getSemantics(find.text(title)),
        isSemantics(label: title, isHeader: true),
      );
    }
    semantics.dispose();
  });

  for (final (label, size, scale) in [
    ('small phone, 200 % text', const Size(320, 640), 2.0),
    ('tablet', const Size(1024, 1366), 1.0),
  ]) {
    testWidgets('renders without overflow on $label', (tester) async {
      await _pump(
        tester,
        reports: _FakeReports(),
        positions: _FakePositions(granted: false, position: _here),
        size: size,
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Choisir le magasin moi-même'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _searchByName(WidgetTester tester, String text) async {
  await tester.tap(find.text('Choisir le magasin moi-même'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Rechercher le magasin'),
    text,
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _proposeChezMama(WidgetTester tester) async {
  await tester.tap(find.text('Mon magasin n’est pas référencé'));
  await tester.pumpAndSettle();
  expect(find.textContaining('10 personnes'), findsWidgets);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Ville'),
    'Libreville',
  );
  await tester.tap(find.text('Envoyer ma position'));
  await tester.pumpAndSettle();
}

void storeProposalTests() {
  testWidgets('a missing store can be proposed with the user position', (
    tester,
  ) async {
    final reports = _FakeReports(found: const []);
    final positions = _FakePositions(granted: false, position: _here);
    await _pump(tester, reports: reports, positions: positions);
    await _searchByName(tester, 'Chez Mama');
    expect(find.text('Aucun magasin trouvé.'), findsOneWidget);

    await _proposeChezMama(tester);
    expect(reports.proposals, ['Chez Mama|Libreville|']);
    expect(positions.locateCalls, 1);
    expect(
      find.text('Merci ! Magasin signalé par 3 personne(s) sur 10.'),
      findsOneWidget,
    );
  });

  testWidgets('the tenth proposal selects the created store', (tester) async {
    final reports = _FakeReports(
      found: const [],
      proposal: const StoreProposalResult(
        status: 'created',
        sightings: 10,
        required: 10,
        store: _unplaced,
      ),
    );
    await _pump(
      tester,
      reports: reports,
      positions: _FakePositions(granted: false, position: _here),
    );
    await _searchByName(tester, 'Kiosque');
    await _proposeChezMama(tester);
    expect(find.textContaining('Magasin ajouté'), findsOneWidget);
    expect(find.text('Changer'), findsOneWidget);
  });

  testWidgets('an already referenced store is chosen instead', (tester) async {
    final reports = _FakeReports(found: const [])
      ..proposalError = const StoreProposalConflict(
        'Ce magasin est déjà référencé.',
        existingStore: _annex,
      );
    await _pump(
      tester,
      reports: reports,
      positions: _FakePositions(granted: false, position: _here),
    );
    await _searchByName(tester, 'Annexe');
    await _proposeChezMama(tester);
    expect(find.textContaining('déjà référencé'), findsOneWidget);
    expect(find.textContaining('Annexe nord'), findsOneWidget);
  });

  testWidgets('an imprecise position is not sent', (tester) async {
    final reports = _FakeReports(found: const []);
    await _pump(
      tester,
      reports: reports,
      positions: _FakePositions(
        granted: false,
        position: const UserPosition.found(0.4162, 9.4673, accuracyM: 300),
      ),
    );
    await _searchByName(tester, 'Chez Mama');
    await _proposeChezMama(tester);
    expect(reports.proposals, isEmpty);
    expect(find.textContaining('Position trop imprécise'), findsOneWidget);
  });

  testWidgets('a chosen store without position can be located once', (
    tester,
  ) async {
    final reports = _FakeReports(found: const [_unplaced]);
    final positions = _FakePositions(granted: false, position: _here);
    await _pump(tester, reports: reports, positions: positions);
    await _searchByName(tester, 'Kiosque');
    await tester.tap(find.text('Kiosque du rond-point').first);
    await tester.pumpAndSettle();

    expect(positions.locateCalls, 0);
    await tester.tap(find.text('Aider à le localiser'));
    await tester.pumpAndSettle();
    expect(find.text('Aider à localiser ce magasin ?'), findsOneWidget);
    await tester.tap(find.text('Envoyer ma position'));
    await tester.pumpAndSettle();

    expect(reports.located, [_unplaced.id]);
    expect(
      find.textContaining('Position enregistrée (3 sur 10)'),
      findsOneWidget,
    );
    expect(find.text('Aider à le localiser'), findsNothing);
  });

  testWidgets('declining the consent sends nothing', (tester) async {
    final reports = _FakeReports(found: const [_unplaced]);
    final positions = _FakePositions(granted: false, position: _here);
    await _pump(tester, reports: reports, positions: positions);
    await _searchByName(tester, 'Kiosque');
    await tester.tap(find.text('Kiosque du rond-point').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aider à le localiser'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non merci'));
    await tester.pumpAndSettle();
    expect(positions.locateCalls, 0);
    expect(reports.located, isEmpty);
  });
}
