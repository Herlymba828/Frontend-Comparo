import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The MVP reads offline and never writes offline: no price report is kept on
/// the device to be sent later (a price entered without a network would be a
/// price nobody checked, sent hours after it was seen). This is a tripwire,
/// not a proof: it fails if the former queue, or a storage package that only
/// a queue of pending writes would need, comes back. Drift stays allowed: it
/// holds the read-only offline cache.
void main() {
  final sources = [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ];

  // Code lines only: a comment may still explain what was removed.
  String codeOf(File file) => file
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n')
      .toLowerCase();

  test('the sources are found', () {
    expect(sources, isNotEmpty);
  });

  test('the former outbox and its queued reports are gone from the code', () {
    for (final file in sources) {
      final code = codeOf(file);
      final path = file.path.replaceAll(r'\', '/');
      expect(code.contains('outbox'), isFalse, reason: path);
      expect(code.contains('queuedreport'), isFalse, reason: path);
    }
  });

  test('no document store for pending writes is imported', () {
    for (final file in sources) {
      final code = file.readAsStringSync();
      final path = file.path.replaceAll(r'\', '/');
      for (final package in _pendingWriteStores) {
        expect(
          code.contains('package:$package/'),
          isFalse,
          reason: '$path $package',
        );
      }
    }
  });

  test('no such storage package is a dependency of the app', () {
    final declared = File('pubspec.yaml')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('#'))
        .map((line) => line.trim())
        .toList();
    for (final package in _pendingWriteStores) {
      expect(
        declared.any((line) => line.startsWith('$package:')),
        isFalse,
        reason: package,
      );
    }
  });
}

/// Key-value and document stores the old queue used or that a new one would
/// reach for. Not Drift (the offline cache) nor path_provider (cache folders).
const _pendingWriteStores = [
  'sembast',
  'sembast_web',
  'hive',
  'hive_flutter',
  'isar',
  'isar_flutter_libs',
  'sqflite',
];
