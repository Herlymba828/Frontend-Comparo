import 'dart:io';

import 'package:comparo_ui/comparo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _fontsLoaded = false;

/// Charge les vraies polices (Bricolage Grotesque, Manrope, Material Icons) :
/// sans elles, flutter_test dessine des blocs et les captures ne veulent rien dire.
Future<void> loadComparoFonts() async {
  if (_fontsLoaded) return;
  Future<void> load(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  // Dans une application, les polices du paquet portent le préfixe du paquet.
  await load('packages/comparo_ui/Bricolage Grotesque',
      'fonts/BricolageGrotesque.ttf');
  await load('packages/comparo_ui/Manrope', 'fonts/Manrope.ttf');
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = flutterRoot == null
      ? null
      : File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons != null && icons.existsSync()) {
    await load('MaterialIcons', icons.path);
  }
  _fontsLoaded = true;
}

/// Monte un widget dans le thème Comparo, à la taille d'un téléphone de référence (390 × 844).
Future<void> pumpComparo(WidgetTester tester, Widget child,
    {bool dark = false,
    Size size = const Size(390, 844),
    bool settle = true}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? ComparoTheme.dark() : ComparoTheme.light(),
    home: child,
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget inScaffold(Widget child) => Builder(
      builder: (context) => Scaffold(
        backgroundColor: context.comparo.canvas,
        body: Center(
            child: Padding(padding: const EdgeInsets.all(20), child: child)),
      ),
    );
