import 'package:drift/drift.dart';

part 'offline_cache_database.g.dart';

/// Réponses API mises en cache pour la lecture hors ligne.
@DataClassName('CacheEntryRow')
class CacheEntries extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get payload => text()();
  DateTimeColumn get cachedAtUtc => dateTime()();
  DateTimeColumn get lastAccessedAtUtc => dateTime()();
  IntColumn get byteSize => integer()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

@DriftDatabase(tables: [CacheEntries])
class OfflineCacheDatabase extends _$OfflineCacheDatabase {
  OfflineCacheDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        'CREATE INDEX cache_entries_eviction '
        'ON cache_entries (last_accessed_at_utc, cached_at_utc)',
      );
    },
  );
}
