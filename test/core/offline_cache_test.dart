import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/storage/cache_storage.dart';
import 'package:frontend/core/storage/cache_storage_io.dart';
import 'package:frontend/core/storage/offline_cache.dart';
import 'package:frontend/core/storage/offline_cache_database.dart';

void main() {
  test('an empty cache returns no value', () async {
    final cache = OfflineCache(storage: MemoryCacheStorage());

    expect(await cache.read('product:15'), isNull);
  });

  test('a recent cache entry remains available and unexpired', () async {
    final now = DateTime.utc(2026, 10, 21);
    final cache = OfflineCache(storage: MemoryCacheStorage(), now: () => now);

    await cache.write('product:15', {'id': 15});
    final result = await cache.read('product:15');

    expect(result?.value, {'id': 15});
    expect(result?.cachedAtUtc, now);
    expect(result?.isExpired, isFalse);
  });

  test('an entry just under 7 days old is not expired', () async {
    var now = DateTime.utc(2026, 10, 1);
    final cache = OfflineCache(storage: MemoryCacheStorage(), now: () => now);

    await cache.write('product:15', {'id': 15});
    now = now.add(const Duration(days: 7) - const Duration(seconds: 1));

    expect((await cache.read('product:15'))?.isExpired, isFalse);
  });

  test('an entry exactly 7 days old is expired but still readable', () async {
    var now = DateTime.utc(2026, 10, 1);
    final cache = OfflineCache(storage: MemoryCacheStorage(), now: () => now);

    await cache.write('product:15', {'id': 15});
    now = now.add(const Duration(days: 7));
    final result = await cache.read('product:15');

    expect(result?.value, {'id': 15});
    expect(result?.isExpired, isTrue);
  });

  test('a corrupt entry is removed and treated as a cache miss', () async {
    final storage = MemoryCacheStorage();
    final now = DateTime.utc(2026, 10, 1);
    await storage.write(
      CacheRecord(
        key: 'product:15',
        payload: '{invalid json',
        cachedAtUtc: now,
        lastAccessedAtUtc: now,
        byteSize: 13,
      ),
    );
    final cache = OfflineCache(storage: storage);

    expect(await cache.read('product:15'), isNull);
    expect(storage.records, isEmpty);
  });

  test('an unavailable storage degrades to a cache miss', () async {
    final cache = OfflineCache(storage: _FailingStorage());

    await cache.write('product:15', {'id': 15});
    expect(await cache.read('product:15'), isNull);
  });

  test('reading an entry refreshes its last access time', () async {
    final storage = MemoryCacheStorage();
    var now = DateTime.utc(2026, 10, 1);
    final cache = OfflineCache(storage: storage, now: () => now);

    await cache.write('product:15', {'id': 15});
    now = now.add(const Duration(hours: 3));
    await cache.read('product:15');

    final record = await storage.read('product:15');
    expect(record?.cachedAtUtc, DateTime.utc(2026, 10, 1));
    expect(record?.lastAccessedAtUtc, now);
  });

  test('clear removes every offline entry', () async {
    final storage = MemoryCacheStorage();
    final cache = OfflineCache(storage: storage);

    await cache.write('product:15', {'id': 15});
    await cache.write('product:16', {'id': 16});
    await cache.clear();

    expect(storage.records, isEmpty);
  });

  group('SQLite storage', () {
    late OfflineCacheDatabase database;
    late DriftCacheStorage storage;

    setUp(() {
      database = OfflineCacheDatabase(NativeDatabase.memory());
      storage = DriftCacheStorage(database);
    });

    tearDown(() => database.close());

    test('persists metadata and payload by request key', () async {
      var now = DateTime.utc(2026, 10, 1, 8);
      final cache = OfflineCache(storage: storage, now: () => now);

      await cache.write('catalog-search:riz:1', {'count': 1});
      now = now.add(const Duration(days: 8));
      final result = await cache.read('catalog-search:riz:1');

      expect(result?.value, {'count': 1});
      expect(result?.cachedAtUtc, DateTime.utc(2026, 10, 1, 8));
      expect(result?.isExpired, isTrue);
      expect(await storage.totalBytes(), '{"count":1}'.length);
    });

    test('orders eviction by last access, then by age', () async {
      DateTime at(int hour) => DateTime.utc(2026, 10, 1, hour);
      Future<void> put(String key, DateTime cached, DateTime accessed) =>
          storage.write(
            CacheRecord(
              key: key,
              payload: '{}',
              cachedAtUtc: cached,
              lastAccessedAtUtc: accessed,
              byteSize: 2,
            ),
          );

      await put('recent', at(1), at(9));
      await put('old-tie', at(1), at(5));
      await put('new-tie', at(3), at(5));
      await put('stale', at(2), at(2));

      final order = await storage.evictionOrder();
      expect(order.map((entry) => entry.key), [
        'stale',
        'old-tie',
        'new-tie',
        'recent',
      ]);
    });

    test('evicts least recently used entries above 100 MiB', () async {
      var now = DateTime.utc(2026, 10, 1);
      final cache = OfflineCache(storage: storage, now: () => now);
      final chunk = 'x' * (40 * 1024 * 1024);

      await cache.write('a', {'data': chunk});
      now = now.add(const Duration(minutes: 1));
      await cache.write('b', {'data': chunk});
      now = now.add(const Duration(minutes: 1));
      await cache.read('a');
      now = now.add(const Duration(minutes: 1));
      await cache.write('c', {'data': chunk});

      expect(await storage.read('b'), isNull);
      expect(await storage.read('a'), isNotNull);
      expect(await storage.read('c'), isNotNull);
      expect(
        await storage.totalBytes(),
        lessThanOrEqualTo(offlineCacheMaxBytes),
      );
    });
  });
}

class _FailingStorage implements CacheStorage {
  Never _fail() => throw Exception('storage unavailable');

  @override
  Future<void> clear() async => _fail();

  @override
  Future<void> delete(String key) async => _fail();

  @override
  Future<List<({String key, int byteSize})>> evictionOrder() async => _fail();

  @override
  Future<CacheRecord?> read(String key) async => _fail();

  @override
  Future<void> touch(String key, DateTime lastAccessedAtUtc) async => _fail();

  @override
  Future<int> totalBytes() async => _fail();

  @override
  Future<void> write(CacheRecord record) async => _fail();
}
