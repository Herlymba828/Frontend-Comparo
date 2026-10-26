import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_storage.dart';
import 'offline_cache_database.dart';

CacheStorage createCacheStorage() {
  _removeLegacyFileCache();
  return DriftCacheStorage(
    OfflineCacheDatabase(driftDatabase(name: 'offline_cache')),
  );
}

/// Cache SQLite (Drift) : métadonnées en colonnes, éviction en SQL.
class DriftCacheStorage implements CacheStorage {
  DriftCacheStorage(this._database);

  final OfflineCacheDatabase _database;

  $CacheEntriesTable get _entries => _database.cacheEntries;

  @override
  Future<void> clear() => _database.delete(_entries).go();

  @override
  Future<void> delete(String key) => (_database.delete(
    _entries,
  )..where((row) => row.cacheKey.equals(key))).go();

  @override
  Future<List<({String key, int byteSize})>> evictionOrder() async {
    final query = _database.selectOnly(_entries)
      ..addColumns([_entries.cacheKey, _entries.byteSize])
      ..orderBy([
        OrderingTerm.asc(_entries.lastAccessedAtUtc),
        OrderingTerm.asc(_entries.cachedAtUtc),
      ]);
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          key: row.read(_entries.cacheKey)!,
          byteSize: row.read(_entries.byteSize)!,
        ),
    ];
  }

  @override
  Future<CacheRecord?> read(String key) async {
    final row = await (_database.select(
      _entries,
    )..where((row) => row.cacheKey.equals(key))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return CacheRecord(
      key: row.cacheKey,
      payload: row.payload,
      cachedAtUtc: row.cachedAtUtc.toUtc(),
      lastAccessedAtUtc: row.lastAccessedAtUtc.toUtc(),
      byteSize: row.byteSize,
    );
  }

  @override
  Future<void> touch(String key, DateTime lastAccessedAtUtc) =>
      (_database.update(
        _entries,
      )..where((row) => row.cacheKey.equals(key))).write(
        CacheEntriesCompanion(
          lastAccessedAtUtc: Value(lastAccessedAtUtc.toUtc()),
        ),
      );

  @override
  Future<int> totalBytes() async {
    final total = _entries.byteSize.sum();
    final row = await (_database.selectOnly(
      _entries,
    )..addColumns([total])).getSingle();
    return row.read(total) ?? 0;
  }

  @override
  Future<void> write(CacheRecord record) => _database
      .into(_entries)
      .insertOnConflictUpdate(
        CacheEntriesCompanion.insert(
          cacheKey: record.key,
          payload: record.payload,
          cachedAtUtc: record.cachedAtUtc.toUtc(),
          lastAccessedAtUtc: record.lastAccessedAtUtc.toUtc(),
          byteSize: record.byteSize,
        ),
      );
}

/// Supprime l'ancien cache sur fichiers JSON, remplacé par SQLite.
Future<void> _removeLegacyFileCache() async {
  try {
    final support = await getApplicationSupportDirectory();
    final legacy = Directory('${support.path}/offline-cache');
    if (await legacy.exists()) {
      await legacy.delete(recursive: true);
    }
  } on Exception catch (error) {
    debugPrint('Unable to remove the legacy offline cache: $error');
  }
}
