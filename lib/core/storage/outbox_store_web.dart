import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast_web/sembast_web.dart';

import 'outbox_store.dart';

OutboxStore createOutboxStore() => IndexedDbOutboxStore();

final _database = databaseFactoryWeb.openDatabase('comparateur-prix-outbox');
final _records = StoreRef<String, Object?>.main();
const _entriesKey = 'entries';
const _photoPrefix = 'photo:';

class IndexedDbOutboxStore implements OutboxStore {
  Future<Database> get _db => _database;

  String _photoKey(String id) {
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id');
    }
    return '$_photoPrefix$id';
  }

  @override
  Future<List<Map<String, dynamic>>> readAll() async {
    final value = await _records.record(_entriesKey).get(await _db);
    if (value is! List) {
      return [];
    }
    return [
      for (final entry in value)
        if (entry is Map) Map<String, dynamic>.from(entry),
    ];
  }

  @override
  Future<void> writeAll(List<Map<String, dynamic>> entries) async {
    await _records.record(_entriesKey).put(await _db, entries);
  }

  @override
  Future<void> savePhoto(String id, Uint8List bytes) async {
    await _records.record(_photoKey(id)).put(await _db, Blob(bytes));
  }

  @override
  Future<Uint8List?> readPhoto(String id) async {
    final value = await _records.record(_photoKey(id)).get(await _db);
    if (value is Blob) {
      return Uint8List.fromList(value.bytes);
    }
    if (value is List) {
      return Uint8List.fromList(value.whereType<int>().toList());
    }
    return null;
  }

  @override
  Future<void> deletePhoto(String id) async {
    await _records.record(_photoKey(id)).delete(await _db);
  }

  @override
  Future<int> totalPhotoBytes() async {
    final db = await _db;
    final keys = await _records.findKeys(db);
    var total = 0;
    for (final key in keys.where((key) => key.startsWith(_photoPrefix))) {
      final value = await _records.record(key).get(db);
      if (value is Blob) {
        total += value.length;
      } else if (value is List) {
        total += value.length;
      }
    }
    return total;
  }
}
