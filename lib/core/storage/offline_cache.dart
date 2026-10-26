import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cache_storage.dart';

const offlineCacheMaxBytes = 100 * 1024 * 1024;
const offlineCacheMaxAge = Duration(days: 7);

class OfflineCacheEntry {
  const OfflineCacheEntry({
    required this.value,
    required this.cachedAtUtc,
    required this.isExpired,
  });

  final Map<String, dynamic> value;
  final DateTime cachedAtUtc;
  final bool isExpired;
}

/// Cache de lecture : expiration à 7 jours (les entrées expirées restent
/// lisibles), plafond de 100 Mio, éviction LRU puis par ancienneté.
class OfflineCache {
  OfflineCache({CacheStorage? storage, DateTime Function()? now})
    : _injectedStorage = storage,
      _now = now ?? DateTime.now;

  final CacheStorage? _injectedStorage;

  /// Ouvert au premier accès : aucune base n'est créée tant que le cache
  /// n'est pas utilisé.
  late final CacheStorage _storage = _injectedStorage ?? createCacheStorage();
  final DateTime Function() _now;
  Future<void> _pendingWrite = Future<void>.value();

  Future<OfflineCacheEntry?> read(String key) async {
    try {
      final record = await _storage.read(key);
      if (record == null) {
        return null;
      }

      final value = jsonDecode(record.payload);
      if (value is! Map<String, dynamic>) {
        await _deleteSafely(key);
        return null;
      }

      await _serialize(() => _storage.touch(key, _now().toUtc()));

      final age = _now().toUtc().difference(record.cachedAtUtc);
      return OfflineCacheEntry(
        value: value,
        cachedAtUtc: record.cachedAtUtc,
        isExpired: age >= offlineCacheMaxAge,
      );
    } on FormatException catch (error) {
      debugPrint('Ignoring malformed offline cache entry: $error');
      await _deleteSafely(key);
      return null;
    } on Exception catch (error) {
      debugPrint('Offline cache read failed: $error');
      return null;
    }
  }

  Future<void> write(String key, Map<String, dynamic> value) async {
    await _serialize(() async {
      try {
        final payload = jsonEncode(value);
        final byteSize = utf8.encode(payload).length;
        if (byteSize > offlineCacheMaxBytes) {
          debugPrint('Skipping offline cache entry larger than 100 MiB.');
          return;
        }

        final timestamp = _now().toUtc();
        await _storage.write(
          CacheRecord(
            key: key,
            payload: payload,
            cachedAtUtc: timestamp,
            lastAccessedAtUtc: timestamp,
            byteSize: byteSize,
          ),
        );
        await _evictUntilWithinLimit();
      } on Exception catch (error) {
        debugPrint('Offline cache write failed: $error');
      }
    });
  }

  /// Efface toutes les données hors ligne (préférences et jetons exclus).
  Future<void> clear() async {
    await _serialize(_storage.clear);
  }

  Future<void> _evictUntilWithinLimit() async {
    var totalBytes = await _storage.totalBytes();
    if (totalBytes <= offlineCacheMaxBytes) {
      return;
    }
    for (final entry in await _storage.evictionOrder()) {
      if (totalBytes <= offlineCacheMaxBytes) {
        break;
      }
      await _storage.delete(entry.key);
      totalBytes -= entry.byteSize;
    }
  }

  Future<void> _deleteSafely(String key) async {
    try {
      await _storage.delete(key);
    } on Exception catch (error) {
      debugPrint('Unable to remove invalid offline cache entry: $error');
    }
  }

  Future<void> _serialize(Future<void> Function() action) {
    final operation = _pendingWrite.then((_) => action());
    _pendingWrite = operation.catchError((Object error) {
      debugPrint('Offline cache operation failed: $error');
    });
    return operation;
  }
}
