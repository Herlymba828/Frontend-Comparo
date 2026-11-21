import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/network/connectivity.dart';
import 'package:frontend/core/storage/outbox_store.dart';
import 'package:frontend/features/contributions/price_report_repository.dart';
import 'package:frontend/features/contributions/report_outbox.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';

class _Online implements ConnectivityService {
  @override
  Future<bool> hasNetwork() async => true;

  @override
  Stream<bool> get networkChanges => const Stream.empty();
}

class _Changing implements ConnectivityService {
  _Changing(this.networkChanges);

  @override
  final Stream<bool> networkChanges;

  @override
  Future<bool> hasNetwork() async => true;
}

/// Answers each submission with the next scripted outcome.
class _ScriptedRepository implements PriceReportRepository {
  _ScriptedRepository(this.outcomes);

  final List<Object> outcomes;
  final sent = <({String? reference, DateTime? observedAt, bool confirmed})>[];

  @override
  Future<int> submit(
    PriceReportDraft draft, {
    String? clientReference,
    DateTime? observedAt,
  }) async {
    sent.add((
      reference: clientReference,
      observedAt: observedAt,
      confirmed: draft.confirmOutlier,
    ));
    final outcome = outcomes.removeAt(0);
    if (outcome is Exception) {
      throw outcome;
    }
    return outcome as int;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _store = ReportStore(
  id: 4,
  name: 'Mbolo',
  merchantName: 'Mbolo',
  street: '',
  city: 'Libreville',
);

PriceReportDraft _draft({PhotoAttachment? photo}) => PriceReportDraft(
  store: _store,
  locationMethod: LocationMethod.manual,
  productName: 'Riz 1 kg',
  price: '1250',
  quantity: '1',
  unitCode: 'kg',
  photo: photo,
);

const _offline = ApiException(kind: ApiErrorKind.offline);

void main() {
  late MemoryOutboxStore store;

  ProviderContainer container(List<Object> outcomes, {int accountId = 17}) {
    final repository = _ScriptedRepository(outcomes);
    final container = ProviderContainer(
      overrides: [
        outboxStoreProvider.overrideWithValue(store),
        priceReportRepositoryProvider.overrideWithValue(repository),
        connectivityServiceProvider.overrideWithValue(_Online()),
        activeAccountIdProvider.overrideWithValue(accountId),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => store = MemoryOutboxStore());

  test('a report kept offline survives a restart and is sent once', () async {
    final first = container([_offline]);
    final queued = await first
        .read(reportOutboxProvider.notifier)
        .enqueue(
          _draft(
            photo: PhotoAttachment(
              bytes: Uint8List.fromList([1, 2, 3]),
              filename: 'p.jpg',
            ),
          ),
        );
    await first.read(reportOutboxProvider.notifier).sync();
    expect(
      first.read(reportOutboxProvider).single.status,
      QueuedStatus.pending,
    );
    expect(store.photos, contains(queued.id));

    // A new session reads the queue back from the store.
    final second = container([42]);
    final outbox = second.read(reportOutboxProvider.notifier);
    await outbox.ready();
    expect(second.read(reportOutboxProvider).single.id, queued.id);
    expect(await outbox.sync(), 1);
    expect(second.read(reportOutboxProvider), isEmpty);
    expect(store.photos, isEmpty);
  });

  test('the reference and the moment seen go with the report', () async {
    final c = container([7]);
    final outbox = c.read(reportOutboxProvider.notifier);
    final queued = await outbox.enqueue(_draft());
    await outbox.sync();
    final repository =
        c.read(priceReportRepositoryProvider) as _ScriptedRepository;
    expect(repository.sent.single.reference, queued.id);
    expect(repository.sent.single.observedAt, queued.createdAt);
  });

  test('an unusual price waits for the user, then leaves confirmed', () async {
    final c = container([
      const UnusualPriceException(
        'Prix très éloigné.',
        PriceCheck(sampleSize: 6, isOutlier: true),
      ),
      9,
    ]);
    final outbox = c.read(reportOutboxProvider.notifier);
    final queued = await outbox.enqueue(_draft());
    await outbox.sync();
    final waiting = c.read(reportOutboxProvider).single;
    expect(waiting.status, QueuedStatus.needsConfirmation);
    expect(waiting.message, 'Prix très éloigné.');
    expect(waiting.journal.last, contains('Prix inhabituel'));

    await outbox.confirmUnusual(queued.id);
    expect(c.read(reportOutboxProvider), isEmpty);
    final repository =
        c.read(priceReportRepositoryProvider) as _ScriptedRepository;
    expect(repository.sent.last.confirmed, isTrue);
  });

  test('a report already received is not lost nor sent twice', () async {
    final c = container([
      const DuplicateReportException(
        message: 'Déjà relevé.',
        existingId: 3,
        isMine: true,
      ),
    ]);
    final outbox = c.read(reportOutboxProvider.notifier);
    await outbox.enqueue(_draft());
    expect(await outbox.sync(), 1);
    expect(c.read(reportOutboxProvider), isEmpty);
  });

  test('someone else s report is a conflict the user resolves', () async {
    final c = container([
      const DuplicateReportException(
        message: 'Déjà relevé.',
        existingId: 3,
        isMine: false,
      ),
    ]);
    final outbox = c.read(reportOutboxProvider.notifier);
    final queued = await outbox.enqueue(_draft());
    await outbox.sync();
    expect(c.read(reportOutboxProvider).single.status, QueuedStatus.conflict);
    await outbox.discard(queued.id);
    expect(c.read(reportOutboxProvider), isEmpty);
  });

  test(
    'a server error keeps the report waiting, a refusal keeps it to read',
    () {
      expect(
        isOfflineError(
          const ApiException(kind: ApiErrorKind.http, statusCode: 503),
        ),
        isTrue,
      );
      expect(
        isOfflineError(
          const ApiException(kind: ApiErrorKind.http, statusCode: 400),
        ),
        isFalse,
      );
      expect(
        isOfflineError(
          const ApiException(kind: ApiErrorKind.http, statusCode: 401),
        ),
        isFalse,
      );
      expect(
        isOfflineError(
          const ApiException(kind: ApiErrorKind.http, statusCode: 429),
        ),
        isFalse,
      );
    },
  );

  test('a different account cannot send a queued report', () async {
    final first = container([_offline]);
    final queued = await first
        .read(reportOutboxProvider.notifier)
        .enqueue(_draft());
    await first.read(reportOutboxProvider.notifier).sync();

    final otherAccount = container([], accountId: 29);
    final outbox = otherAccount.read(reportOutboxProvider.notifier);
    await outbox.ready();
    expect(await outbox.sync(), 0);
    expect(otherAccount.read(reportOutboxProvider).single.id, queued.id);
    expect(
      (otherAccount.read(
        priceReportRepositoryProvider,
      ) as _ScriptedRepository).sent,
      isEmpty,
    );

    final originalAccount = container([42]);
    final originalOutbox = originalAccount.read(reportOutboxProvider.notifier);
    await originalOutbox.ready();
    expect(await originalOutbox.sync(), 1);
    expect(originalAccount.read(reportOutboxProvider), isEmpty);
  });

  test('a 401 waits for the original account to authenticate again', () async {
    final c = container([
      const ApiException(kind: ApiErrorKind.http, statusCode: 401),
      42,
    ]);
    final outbox = c.read(reportOutboxProvider.notifier);
    await outbox.enqueue(_draft());
    await outbox.sync();
    expect(
      c.read(reportOutboxProvider).single.status,
      QueuedStatus.needsAuthentication,
    );

    expect(await outbox.sync(), 1);
    expect(c.read(reportOutboxProvider), isEmpty);
  });

  test(
    'a 429 is scheduled using Retry-After, not treated as offline',
    () async {
      final c = container([
        const ApiException(
          kind: ApiErrorKind.http,
          statusCode: 429,
          retryAfterSeconds: 3600,
        ),
      ]);
      final outbox = c.read(reportOutboxProvider.notifier);
      await outbox.enqueue(_draft());
      await outbox.sync();

      final queued = c.read(reportOutboxProvider).single;
      expect(queued.status, QueuedStatus.rateLimited);
      expect(queued.retryAtUtc, isNotNull);
      expect(
        queued.retryAtUtc!.difference(DateTime.now().toUtc()).inMinutes,
        greaterThanOrEqualTo(59),
      );
    },
  );

  test('legacy reports without an owner stay unsent until discarded', () async {
    store.entries = [
      {
        'id': 'legacy-report',
        'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'store_id': 4,
        'store_name': 'Mbolo',
        'product_name': 'Riz 1 kg',
        'price': '1250',
        'status': 'pending',
      },
    ];
    final c = container([]);
    final outbox = c.read(reportOutboxProvider.notifier);
    await outbox.ready();

    expect(c.read(reportOutboxProvider).single.status, QueuedStatus.unassigned);
    expect(await outbox.sync(), 0);
    expect(
      (c.read(priceReportRepositoryProvider) as _ScriptedRepository).sent,
      isEmpty,
    );

    await outbox.discardUnassigned();
    expect(c.read(reportOutboxProvider), isEmpty);
  });

  // MVP: offline, the app only reads its cache; it never records nor sends a
  // price report by itself.
  group('no write without network (MVP)', () {
    test('nothing leaves when the network comes back', () async {
      final network = StreamController<bool>();
      addTearDown(network.close);
      final c = ProviderContainer(
        overrides: [
          outboxStoreProvider.overrideWithValue(store),
          priceReportRepositoryProvider.overrideWithValue(
            _ScriptedRepository([42]),
          ),
          connectivityServiceProvider.overrideWithValue(
            _Changing(network.stream),
          ),
          activeAccountIdProvider.overrideWithValue(17),
        ],
      );
      addTearDown(c.dispose);
      c.listen(reconnectProvider, (_, _) {});
      final outbox = c.read(reportOutboxProvider.notifier);
      await outbox.enqueue(_draft());
      network
        ..add(false)
        ..add(true); // the network comes back
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      expect(c.read(reconnectProvider), greaterThan(0));
      expect(
        (c.read(priceReportRepositoryProvider) as _ScriptedRepository).sent,
        isEmpty,
      );
      expect(c.read(reportOutboxProvider).single.status, QueuedStatus.pending);
    });

    test('ending the session empties the queue and its photos', () async {
      final c = container([]);
      final outbox = c.read(reportOutboxProvider.notifier);
      await outbox.enqueue(
        _draft(
          photo: PhotoAttachment(
            bytes: Uint8List.fromList([1, 2, 3]),
            filename: 'p.jpg',
          ),
        ),
      );
      await outbox.clearAll();
      expect(c.read(reportOutboxProvider), isEmpty);
      expect(store.entries, isEmpty);
      expect(store.photos, isEmpty);
    });

    test('no app code queues a report or sends the queue by itself', () {
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in sources) {
        final code = file.readAsStringSync();
        final path = file.path.replaceAll(r'\', '/');
        if (!path.endsWith('contributions/report_outbox.dart')) {
          expect(code.contains('.enqueue('), isFalse, reason: path);
        }
        if (path.endsWith('app/bootstrap.dart')) {
          expect(code.contains('reportOutbox'), isFalse, reason: path);
        }
      }
    });
  });
}
