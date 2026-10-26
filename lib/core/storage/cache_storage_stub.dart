import 'cache_storage.dart';

/// Web : pas de cache persistant dans ce MVP (Android prioritaire).
CacheStorage createCacheStorage() => MemoryCacheStorage();
