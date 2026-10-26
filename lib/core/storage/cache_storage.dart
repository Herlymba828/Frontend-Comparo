export 'cache_storage_stub.dart'
    if (dart.library.io) 'cache_storage_io.dart'
    show createCacheStorage;

/// Une entrée du cache de lecture hors ligne et ses métadonnées locales.
///
/// `cachedAtUtc` et `lastAccessedAtUtc` décrivent la copie locale ; ils ne
/// remplacent jamais les dates métier (observation, validité d'une offre).
class CacheRecord {
  const CacheRecord({
    required this.key,
    required this.payload,
    required this.cachedAtUtc,
    required this.lastAccessedAtUtc,
    required this.byteSize,
  });

  /// Contexte de requête (route et paramètres) qui identifie la réponse.
  final String key;
  final String payload;
  final DateTime cachedAtUtc;
  final DateTime lastAccessedAtUtc;
  final int byteSize;
}

abstract interface class CacheStorage {
  Future<CacheRecord?> read(String key);

  Future<void> write(CacheRecord record);

  Future<void> touch(String key, DateTime lastAccessedAtUtc);

  Future<void> delete(String key);

  Future<int> totalBytes();

  /// Entrées dans l'ordre d'éviction : la moins récemment consultée d'abord,
  /// puis la plus ancienne en cas d'égalité.
  Future<List<({String key, int byteSize})>> evictionOrder();

  Future<void> clear();
}

/// Stockage en mémoire : Web (sans persistance) et tests.
class MemoryCacheStorage implements CacheStorage {
  final records = <String, CacheRecord>{};

  @override
  Future<void> clear() async => records.clear();

  @override
  Future<void> delete(String key) async => records.remove(key);

  @override
  Future<List<({String key, int byteSize})>> evictionOrder() async {
    final ordered = records.values.toList()
      ..sort((left, right) {
        final byAccess = left.lastAccessedAtUtc.compareTo(
          right.lastAccessedAtUtc,
        );
        return byAccess != 0
            ? byAccess
            : left.cachedAtUtc.compareTo(right.cachedAtUtc);
      });
    return [
      for (final record in ordered)
        (key: record.key, byteSize: record.byteSize),
    ];
  }

  @override
  Future<CacheRecord?> read(String key) async => records[key];

  @override
  Future<void> touch(String key, DateTime lastAccessedAtUtc) async {
    final record = records[key];
    if (record == null) {
      return;
    }
    records[key] = CacheRecord(
      key: record.key,
      payload: record.payload,
      cachedAtUtc: record.cachedAtUtc,
      lastAccessedAtUtc: lastAccessedAtUtc,
      byteSize: record.byteSize,
    );
  }

  @override
  Future<int> totalBytes() async =>
      records.values.fold<int>(0, (sum, record) => sum + record.byteSize);

  @override
  Future<void> write(CacheRecord record) async => records[record.key] = record;
}
