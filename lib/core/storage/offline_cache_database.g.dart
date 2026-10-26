// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_cache_database.dart';

// ignore_for_file: type=lint
class $CacheEntriesTable extends CacheEntries
    with TableInfo<$CacheEntriesTable, CacheEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtUtcMeta = const VerificationMeta(
    'cachedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAtUtc = GeneratedColumn<DateTime>(
    'cached_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedAtUtcMeta = const VerificationMeta(
    'lastAccessedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccessedAtUtc =
      GeneratedColumn<DateTime>(
        'last_accessed_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    payload,
    cachedAtUtc,
    lastAccessedAtUtc,
    byteSize,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('cached_at_utc')) {
      context.handle(
        _cachedAtUtcMeta,
        cachedAtUtc.isAcceptableOrUnknown(
          data['cached_at_utc']!,
          _cachedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cachedAtUtcMeta);
    }
    if (data.containsKey('last_accessed_at_utc')) {
      context.handle(
        _lastAccessedAtUtcMeta,
        lastAccessedAtUtc.isAcceptableOrUnknown(
          data['last_accessed_at_utc']!,
          _lastAccessedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtUtcMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  CacheEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheEntryRow(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      cachedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at_utc'],
      )!,
      lastAccessedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed_at_utc'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
    );
  }

  @override
  $CacheEntriesTable createAlias(String alias) {
    return $CacheEntriesTable(attachedDatabase, alias);
  }
}

class CacheEntryRow extends DataClass implements Insertable<CacheEntryRow> {
  final String cacheKey;
  final String payload;
  final DateTime cachedAtUtc;
  final DateTime lastAccessedAtUtc;
  final int byteSize;
  const CacheEntryRow({
    required this.cacheKey,
    required this.payload,
    required this.cachedAtUtc,
    required this.lastAccessedAtUtc,
    required this.byteSize,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload'] = Variable<String>(payload);
    map['cached_at_utc'] = Variable<DateTime>(cachedAtUtc);
    map['last_accessed_at_utc'] = Variable<DateTime>(lastAccessedAtUtc);
    map['byte_size'] = Variable<int>(byteSize);
    return map;
  }

  CacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheEntriesCompanion(
      cacheKey: Value(cacheKey),
      payload: Value(payload),
      cachedAtUtc: Value(cachedAtUtc),
      lastAccessedAtUtc: Value(lastAccessedAtUtc),
      byteSize: Value(byteSize),
    );
  }

  factory CacheEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheEntryRow(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      payload: serializer.fromJson<String>(json['payload']),
      cachedAtUtc: serializer.fromJson<DateTime>(json['cachedAtUtc']),
      lastAccessedAtUtc: serializer.fromJson<DateTime>(
        json['lastAccessedAtUtc'],
      ),
      byteSize: serializer.fromJson<int>(json['byteSize']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payload': serializer.toJson<String>(payload),
      'cachedAtUtc': serializer.toJson<DateTime>(cachedAtUtc),
      'lastAccessedAtUtc': serializer.toJson<DateTime>(lastAccessedAtUtc),
      'byteSize': serializer.toJson<int>(byteSize),
    };
  }

  CacheEntryRow copyWith({
    String? cacheKey,
    String? payload,
    DateTime? cachedAtUtc,
    DateTime? lastAccessedAtUtc,
    int? byteSize,
  }) => CacheEntryRow(
    cacheKey: cacheKey ?? this.cacheKey,
    payload: payload ?? this.payload,
    cachedAtUtc: cachedAtUtc ?? this.cachedAtUtc,
    lastAccessedAtUtc: lastAccessedAtUtc ?? this.lastAccessedAtUtc,
    byteSize: byteSize ?? this.byteSize,
  );
  CacheEntryRow copyWithCompanion(CacheEntriesCompanion data) {
    return CacheEntryRow(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      cachedAtUtc: data.cachedAtUtc.present
          ? data.cachedAtUtc.value
          : this.cachedAtUtc,
      lastAccessedAtUtc: data.lastAccessedAtUtc.present
          ? data.lastAccessedAtUtc.value
          : this.lastAccessedAtUtc,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntryRow(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('cachedAtUtc: $cachedAtUtc, ')
          ..write('lastAccessedAtUtc: $lastAccessedAtUtc, ')
          ..write('byteSize: $byteSize')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(cacheKey, payload, cachedAtUtc, lastAccessedAtUtc, byteSize);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheEntryRow &&
          other.cacheKey == this.cacheKey &&
          other.payload == this.payload &&
          other.cachedAtUtc == this.cachedAtUtc &&
          other.lastAccessedAtUtc == this.lastAccessedAtUtc &&
          other.byteSize == this.byteSize);
}

class CacheEntriesCompanion extends UpdateCompanion<CacheEntryRow> {
  final Value<String> cacheKey;
  final Value<String> payload;
  final Value<DateTime> cachedAtUtc;
  final Value<DateTime> lastAccessedAtUtc;
  final Value<int> byteSize;
  final Value<int> rowid;
  const CacheEntriesCompanion({
    this.cacheKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.cachedAtUtc = const Value.absent(),
    this.lastAccessedAtUtc = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheEntriesCompanion.insert({
    required String cacheKey,
    required String payload,
    required DateTime cachedAtUtc,
    required DateTime lastAccessedAtUtc,
    required int byteSize,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       payload = Value(payload),
       cachedAtUtc = Value(cachedAtUtc),
       lastAccessedAtUtc = Value(lastAccessedAtUtc),
       byteSize = Value(byteSize);
  static Insertable<CacheEntryRow> custom({
    Expression<String>? cacheKey,
    Expression<String>? payload,
    Expression<DateTime>? cachedAtUtc,
    Expression<DateTime>? lastAccessedAtUtc,
    Expression<int>? byteSize,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payload != null) 'payload': payload,
      if (cachedAtUtc != null) 'cached_at_utc': cachedAtUtc,
      if (lastAccessedAtUtc != null) 'last_accessed_at_utc': lastAccessedAtUtc,
      if (byteSize != null) 'byte_size': byteSize,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheEntriesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? payload,
    Value<DateTime>? cachedAtUtc,
    Value<DateTime>? lastAccessedAtUtc,
    Value<int>? byteSize,
    Value<int>? rowid,
  }) {
    return CacheEntriesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      payload: payload ?? this.payload,
      cachedAtUtc: cachedAtUtc ?? this.cachedAtUtc,
      lastAccessedAtUtc: lastAccessedAtUtc ?? this.lastAccessedAtUtc,
      byteSize: byteSize ?? this.byteSize,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (cachedAtUtc.present) {
      map['cached_at_utc'] = Variable<DateTime>(cachedAtUtc.value);
    }
    if (lastAccessedAtUtc.present) {
      map['last_accessed_at_utc'] = Variable<DateTime>(lastAccessedAtUtc.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntriesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('cachedAtUtc: $cachedAtUtc, ')
          ..write('lastAccessedAtUtc: $lastAccessedAtUtc, ')
          ..write('byteSize: $byteSize, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OfflineCacheDatabase extends GeneratedDatabase {
  _$OfflineCacheDatabase(QueryExecutor e) : super(e);
  $OfflineCacheDatabaseManager get managers =>
      $OfflineCacheDatabaseManager(this);
  late final $CacheEntriesTable cacheEntries = $CacheEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cacheEntries];
}

typedef $$CacheEntriesTableCreateCompanionBuilder =
    CacheEntriesCompanion Function({
      required String cacheKey,
      required String payload,
      required DateTime cachedAtUtc,
      required DateTime lastAccessedAtUtc,
      required int byteSize,
      Value<int> rowid,
    });
typedef $$CacheEntriesTableUpdateCompanionBuilder =
    CacheEntriesCompanion Function({
      Value<String> cacheKey,
      Value<String> payload,
      Value<DateTime> cachedAtUtc,
      Value<DateTime> lastAccessedAtUtc,
      Value<int> byteSize,
      Value<int> rowid,
    });

class $$CacheEntriesTableFilterComposer
    extends Composer<_$OfflineCacheDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAtUtc => $composableBuilder(
    column: $table.cachedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccessedAtUtc => $composableBuilder(
    column: $table.lastAccessedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheEntriesTableOrderingComposer
    extends Composer<_$OfflineCacheDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAtUtc => $composableBuilder(
    column: $table.cachedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccessedAtUtc => $composableBuilder(
    column: $table.lastAccessedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheEntriesTableAnnotationComposer
    extends Composer<_$OfflineCacheDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAtUtc => $composableBuilder(
    column: $table.cachedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAccessedAtUtc => $composableBuilder(
    column: $table.lastAccessedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);
}

class $$CacheEntriesTableTableManager
    extends
        RootTableManager<
          _$OfflineCacheDatabase,
          $CacheEntriesTable,
          CacheEntryRow,
          $$CacheEntriesTableFilterComposer,
          $$CacheEntriesTableOrderingComposer,
          $$CacheEntriesTableAnnotationComposer,
          $$CacheEntriesTableCreateCompanionBuilder,
          $$CacheEntriesTableUpdateCompanionBuilder,
          (
            CacheEntryRow,
            BaseReferences<
              _$OfflineCacheDatabase,
              $CacheEntriesTable,
              CacheEntryRow
            >,
          ),
          CacheEntryRow,
          PrefetchHooks Function()
        > {
  $$CacheEntriesTableTableManager(
    _$OfflineCacheDatabase db,
    $CacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> cachedAtUtc = const Value.absent(),
                Value<DateTime> lastAccessedAtUtc = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion(
                cacheKey: cacheKey,
                payload: payload,
                cachedAtUtc: cachedAtUtc,
                lastAccessedAtUtc: lastAccessedAtUtc,
                byteSize: byteSize,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String payload,
                required DateTime cachedAtUtc,
                required DateTime lastAccessedAtUtc,
                required int byteSize,
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion.insert(
                cacheKey: cacheKey,
                payload: payload,
                cachedAtUtc: cachedAtUtc,
                lastAccessedAtUtc: lastAccessedAtUtc,
                byteSize: byteSize,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheEntriesTable, CacheEntryRow>(table),
                  BaseReferences<
                    _$OfflineCacheDatabase,
                    $CacheEntriesTable,
                    CacheEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineCacheDatabase,
      $CacheEntriesTable,
      CacheEntryRow,
      $$CacheEntriesTableFilterComposer,
      $$CacheEntriesTableOrderingComposer,
      $$CacheEntriesTableAnnotationComposer,
      $$CacheEntriesTableCreateCompanionBuilder,
      $$CacheEntriesTableUpdateCompanionBuilder,
      (
        CacheEntryRow,
        BaseReferences<
          _$OfflineCacheDatabase,
          $CacheEntriesTable,
          CacheEntryRow
        >,
      ),
      CacheEntryRow,
      PrefetchHooks Function()
    >;

class $OfflineCacheDatabaseManager {
  final _$OfflineCacheDatabase _db;
  $OfflineCacheDatabaseManager(this._db);
  $$CacheEntriesTableTableManager get cacheEntries =>
      $$CacheEntriesTableTableManager(_db, _db.cacheEntries);
}
