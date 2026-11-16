import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part de pixels qui peut différer d'une capture de référence.
///
/// Le lissage des contours des lettres change d'un système à l'autre (Windows,
/// macOS, Linux) : les mêmes polices, la même mise en page, mais 2,6 à 3 % de
/// pixels différents sur les bords. Un décalage, une couleur ou un texte
/// modifié dépasse ce seuil ; régénérer : flutter test --update-goldens.
const goldenTolerance = 0.04;

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= goldenTolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(
      Uri.parse('${current.basedir}flutter_test_config.dart'),
    );
  }
  await testMain();
}
