import 'outbox_store.dart';

/// Web: kept in memory for the session (Android first in this MVP).
OutboxStore createOutboxStore() => MemoryOutboxStore();
