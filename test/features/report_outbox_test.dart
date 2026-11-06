import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/network/connectivity.dart';
import 'package:frontend/core/storage/outbox_store.dart';
import 'package:frontend/features/contributions/price_report_repository.dart';
import 'package:frontend/features/contributions/report_outbox.dart';

class _Online implements ConnectivityService {
  @override
  Future<bool> hasNetwork() async => true;

  @override
  Stream<bool> get networkChanges => const Stream.empty();
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

  ProviderContainer container(List<Object> outcomes) {
    final repository = _ScriptedRepository(outcomes);
    final container = ProviderContainer(
      overrides: [
        outboxStoreProvider.overrideWithValue(store),
        priceReportRepositoryProvider.overrideWithValue(repository),
        connectivityServiceProvider.overrideWithValue(_Online()),
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
    },
  );
}
