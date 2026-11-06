import 'dart:typed_data';

export 'outbox_store_stub.dart'
    if (dart.library.io) 'outbox_store_io.dart'
    show createOutboxStore;

/// Durable storage of the operations made offline (PJ-028). Unlike the
/// cache, nothing here is ever evicted: an entry leaves only once sent or
/// discarded by the user.
abstract interface class OutboxStore {
  Future<List<Map<String, dynamic>>> readAll();

  Future<void> writeAll(List<Map<String, dynamic>> entries);

  Future<void> savePhoto(String id, Uint8List bytes);

  Future<Uint8List?> readPhoto(String id);

  Future<void> deletePhoto(String id);
}

class MemoryOutboxStore implements OutboxStore {
  List<Map<String, dynamic>> entries = [];
  final Map<String, Uint8List> photos = {};

  @override
  Future<List<Map<String, dynamic>>> readAll() async => [...entries];

  @override
  Future<void> writeAll(List<Map<String, dynamic>> entries) async =>
      this.entries = [...entries];

  @override
  Future<void> savePhoto(String id, Uint8List bytes) async =>
      photos[id] = bytes;

  @override
  Future<Uint8List?> readPhoto(String id) async => photos[id];

  @override
  Future<void> deletePhoto(String id) async => photos.remove(id);
}
