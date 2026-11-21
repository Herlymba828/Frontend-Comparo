import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/storage/outbox_store.dart';
import '../account/account_repository.dart';
import '../identity/data/auth_providers.dart';
import '../stores/stores_repository.dart';
import 'price_report_repository.dart';

const maxQueuedReports = 100;
const maxQueuedPhotoBytes = 50 * 1024 * 1024;

/// Where a report kept offline stands (PJ-028, PJ-029).
enum QueuedStatus {
  /// Stored before account ownership was recorded; never sent automatically.
  unassigned,

  /// Waiting for the network.
  pending,

  /// The originating account must sign in again before sending.
  needsAuthentication,

  /// The server asked the app to wait before trying again.
  rateLimited,

  /// The server finds the price unusual: the user confirms or discards it.
  needsConfirmation,

  /// Someone else reported the same price: the user decides.
  conflict,

  /// The server refused it (too old, store closed...): kept to be read.
  rejected,
}

/// A price report made without network, with what happened to it.
class QueuedReport {
  const QueuedReport({
    required this.id,
    required this.ownerUserId,
    required this.createdAt,
    required this.storeId,
    required this.storeName,
    required this.locationMethod,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.unitCode,
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.productId,
    this.hasPhoto = false,
    this.photoName = '',
    this.displayError = false,
    this.notes = '',
    this.confirmOutlier = false,
    this.message = '',
    this.attempts = 0,
    this.retryAtUtc,
    this.journal = const [],
  });

  /// Also the report's client reference: a replay never makes a copy.
  final String id;

  /// The account that created this report; null only for pre-migration data.
  final int? ownerUserId;

  /// When the price was seen, sent as its observation time.
  final DateTime createdAt;
  final int storeId;
  final String storeName;
  final String locationMethod;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final int? productId;
  final String productName;
  final String price;
  final String quantity;
  final String unitCode;
  final bool hasPhoto;
  final String photoName;
  final bool displayError;
  final String notes;
  final bool confirmOutlier;
  final QueuedStatus status;

  /// The server's explanation for a report that needs the user.
  final String message;
  final int attempts;
  final DateTime? retryAtUtc;

  /// The last events, newest last (PJ-029: nothing changes silently).
  final List<String> journal;

  static const maxJournal = 5;

  QueuedReport copyWith({
    QueuedStatus? status,
    String? message,
    bool? confirmOutlier,
    int? attempts,
    DateTime? retryAtUtc,
    bool clearRetryAt = false,
    String? event,
  }) => QueuedReport(
    id: id,
    ownerUserId: ownerUserId,
    createdAt: createdAt,
    storeId: storeId,
    storeName: storeName,
    locationMethod: locationMethod,
    latitude: latitude,
    longitude: longitude,
    accuracyM: accuracyM,
    productId: productId,
    productName: productName,
    price: price,
    quantity: quantity,
    unitCode: unitCode,
    hasPhoto: hasPhoto,
    photoName: photoName,
    displayError: displayError,
    notes: notes,
    confirmOutlier: confirmOutlier ?? this.confirmOutlier,
    status: status ?? this.status,
    message: message ?? this.message,
    attempts: attempts ?? this.attempts,
    retryAtUtc: clearRetryAt ? null : retryAtUtc ?? this.retryAtUtc,
    journal: event == null
        ? journal
        : [
            ...journal,
            '${DateTime.now().toIso8601String()} $event',
          ].reversed.take(maxJournal).toList().reversed.toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_user_id': ownerUserId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'store_id': storeId,
    'store_name': storeName,
    'location_method': locationMethod,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_m': accuracyM,
    'product_id': productId,
    'product_name': productName,
    'price': price,
    'quantity': quantity,
    'unit_code': unitCode,
    'has_photo': hasPhoto,
    'photo_name': photoName,
    'display_error': displayError,
    'notes': notes,
    'confirm_outlier': confirmOutlier,
    'status': status.name,
    'message': message,
    'attempts': attempts,
    'retry_at_utc': retryAtUtc?.toUtc().toIso8601String(),
    'journal': journal,
  };

  factory QueuedReport.fromJson(Map<String, dynamic> json) {
    final ownerUserId = json['owner_user_id'];
    final retryAt = json['retry_at_utc'];
    final status =
        QueuedStatus.values.asNameMap()[json['status']] ?? QueuedStatus.pending;
    return QueuedReport(
      id: json['id'] as String,
      ownerUserId: ownerUserId is int ? ownerUserId : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      storeId: json['store_id'] as int,
      storeName: json['store_name'] as String? ?? '',
      locationMethod: json['location_method'] as String? ?? 'manual',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String? ?? '',
      price: json['price'] as String? ?? '',
      quantity: json['quantity'] as String? ?? '1',
      unitCode: json['unit_code'] as String? ?? '',
      hasPhoto: json['has_photo'] == true,
      photoName: json['photo_name'] as String? ?? '',
      displayError: json['display_error'] == true,
      notes: json['notes'] as String? ?? '',
      confirmOutlier: json['confirm_outlier'] == true,
      status: ownerUserId is int ? status : QueuedStatus.unassigned,
      message: json['message'] as String? ?? '',
      attempts: json['attempts'] as int? ?? 0,
      retryAtUtc: retryAt is String ? DateTime.tryParse(retryAt) : null,
      journal:
          (json['journal'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// An offline-safe identifier, also accepted as the server's client reference.
String newQueueId() {
  final random = Random.secure();
  final suffix = List.generate(
    12,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
  return '${DateTime.now().millisecondsSinceEpoch}-$suffix';
}

/// True when [error] means "no network": the operation can wait.
bool isOfflineError(Object error) =>
    error is ApiException &&
    (error.kind == ApiErrorKind.offline ||
        error.kind == ApiErrorKind.network ||
        error.kind == ApiErrorKind.timeout ||
        (error.statusCode ?? 0) >= 500);

class OutboxCapacityException implements Exception {
  const OutboxCapacityException(this.message);

  final String message;

  @override
  String toString() => message;
}

final outboxStoreProvider = Provider<OutboxStore>((ref) => createOutboxStore());

final reportOutboxProvider = NotifierProvider<ReportOutbox, List<QueuedReport>>(
  ReportOutbox.new,
);

/// Price reports left on this device by earlier versions of the app.
///
/// MVP rule: offline, the app only shows cached data; it never records a
/// price report. Nothing is sent by itself (no send at start-up, on
/// reconnection or on a timer): the owner sends a left report with the
/// "Envoyer" button while online, or deletes it. The queue is emptied when
/// the session ends.
class ReportOutbox extends Notifier<List<QueuedReport>> {
  late final OutboxStore _store = ref.read(outboxStoreProvider);
  Future<void>? _loading;
  bool _syncing = false;

  @override
  List<QueuedReport> build() {
    _loading = _load();
    return const [];
  }

  Future<void> _load() async {
    final entries = await _store.readAll();
    state = [for (final entry in entries) ?_readable(entry)];
  }

  static QueuedReport? _readable(Map<String, dynamic> entry) {
    try {
      return QueuedReport.fromJson(entry);
    } on FormatException catch (error) {
      debugPrint('Ignoring malformed queued report: $error');
      return null;
    } on TypeError catch (error) {
      debugPrint('Ignoring unreadable queued report: $error');
      return null;
    }
  }

  Future<void> ready() => _loading ?? Future<void>.value();

  Future<void> _save(List<QueuedReport> reports) async {
    await _store.writeAll([for (final report in reports) report.toJson()]);
    state = reports;
  }

  /// Puts a report in the queue, as earlier versions did offline.
  ///
  /// Not used by the app any more (MVP: no report without network); kept to
  /// build the legacy queues the tests check.
  @visibleForTesting
  Future<QueuedReport> enqueue(PriceReportDraft draft) async {
    await ready();
    final ownerUserId = ref.read(activeAccountIdProvider);
    if (ownerUserId == null) {
      throw StateError('A signed-in account is required to queue a report.');
    }
    if (state.length >= maxQueuedReports) {
      throw const OutboxCapacityException(
        'La file hors ligne est pleine. Envoyez ou supprimez des relevés '
        'avant d’en ajouter.',
      );
    }
    final id = newQueueId();
    final photo = draft.photo;
    if (photo != null) {
      final storedPhotoBytes = await _store.totalPhotoBytes();
      if (photo.bytes.length > maxQueuedPhotoBytes - storedPhotoBytes) {
        throw const OutboxCapacityException(
          'L’espace réservé aux photos hors ligne est plein. Envoyez ou '
          'supprimez des relevés avant d’ajouter une photo.',
        );
      }
      await _store.savePhoto(id, photo.bytes);
    }
    final report = QueuedReport(
      id: id,
      ownerUserId: ownerUserId,
      // A clock a few minutes ahead would date the price in the future.
      createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      storeId: draft.store.id,
      storeName: draft.store.name,
      locationMethod: draft.locationMethod.name,
      latitude: draft.position?.latitude,
      longitude: draft.position?.longitude,
      accuracyM: draft.position?.accuracyM,
      productId: draft.productId,
      productName: draft.productName,
      price: draft.price,
      quantity: draft.quantity,
      unitCode: draft.unitCode,
      hasPhoto: photo != null,
      photoName: photo?.filename ?? '',
      displayError: draft.displayError,
      notes: draft.notes,
      confirmOutlier: draft.confirmOutlier,
      status: QueuedStatus.pending,
      journal: [
        '${DateTime.now().toIso8601String()} Gardé sur cet appareil (hors ligne)',
      ],
    );
    try {
      await _save([...state, report]);
    } on Exception {
      if (photo != null) {
        await _store.deletePhoto(id);
      }
      rethrow;
    }
    return report;
  }

  Future<PriceReportDraft> _draft(QueuedReport report) async {
    final bytes = report.hasPhoto ? await _store.readPhoto(report.id) : null;
    final lat = report.latitude;
    final lon = report.longitude;
    return PriceReportDraft(
      store: ReportStore(
        id: report.storeId,
        name: report.storeName,
        merchantName: '',
        street: '',
        city: '',
      ),
      locationMethod:
          LocationMethod.values.asNameMap()[report.locationMethod] ??
          LocationMethod.manual,
      position: lat == null || lon == null
          ? null
          : UserPosition.found(lat, lon, accuracyM: report.accuracyM),
      productId: report.productId,
      productName: report.productName,
      price: report.price,
      quantity: report.quantity,
      unitCode: report.unitCode,
      photo: bytes == null
          ? null
          : PhotoAttachment(bytes: bytes, filename: report.photoName),
      displayError: report.displayError,
      notes: report.notes,
      confirmOutlier: report.confirmOutlier,
    );
  }

  /// Sends the waiting reports, one by one; stops at the first network failure.
  Future<int> sync() async {
    await ready();
    final accountId = ref.read(activeAccountIdProvider);
    if (accountId == null) {
      return 0;
    }
    if (_syncing) {
      return 0;
    }
    _syncing = true;
    var sent = 0;
    try {
      for (final report
          in state
              .where(
                (report) =>
                    report.ownerUserId == accountId &&
                    (report.status == QueuedStatus.pending ||
                        report.status == QueuedStatus.needsAuthentication ||
                        report.status == QueuedStatus.rateLimited),
              )
              .toList()) {
        final retryAt = report.retryAtUtc;
        if (report.status == QueuedStatus.rateLimited &&
            retryAt != null &&
            retryAt.isAfter(DateTime.now().toUtc())) {
          continue; // the server asked to wait: the user tries again later
        }
        final outcome = await _send(report);
        if (outcome == _Outcome.offline ||
            outcome == _Outcome.rateLimited ||
            outcome == _Outcome.needsAuthentication ||
            outcome == _Outcome.accountChanged) {
          break;
        }
        if (outcome == _Outcome.sent) {
          sent++;
        }
      }
    } finally {
      _syncing = false;
    }
    if (sent > 0) {
      ref.invalidate(contributionsProvider(false));
    }
    return sent;
  }

  Future<_Outcome> _send(QueuedReport report) async {
    if (ref.read(activeAccountIdProvider) != report.ownerUserId) {
      return _Outcome.accountChanged;
    }
    final attempts = report.attempts + 1;
    try {
      final draft = await _draft(report);
      if (ref.read(activeAccountIdProvider) != report.ownerUserId) {
        return _Outcome.accountChanged;
      }
      await ref
          .read(priceReportRepositoryProvider)
          .submit(
            draft,
            clientReference: report.id,
            observedAt: report.createdAt,
          );
      await _remove(report.id);
      return _Outcome.sent;
    } on UnusualPriceException catch (error) {
      await _replace(
        report.copyWith(
          status: QueuedStatus.needsConfirmation,
          message: error.message,
          attempts: attempts,
          event: 'Prix inhabituel : votre confirmation est demandée',
        ),
      );
    } on DuplicateReportException catch (error) {
      if (error.isMine) {
        // Already received (an answer lost on the way): nothing is lost.
        await _remove(report.id);
        return _Outcome.sent;
      }
      await _replace(
        report.copyWith(
          status: QueuedStatus.conflict,
          message: error.message,
          attempts: attempts,
          event: 'Déjà relevé par quelqu’un d’autre',
        ),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _replace(
          report.copyWith(
            status: QueuedStatus.needsAuthentication,
            message:
                'Reconnectez-vous au compte d’origine pour envoyer ce '
                'relevé.',
            attempts: attempts,
            clearRetryAt: true,
            event: 'Connexion requise pour reprendre l’envoi',
          ),
        );
        return _Outcome.needsAuthentication;
      }
      if (error.statusCode == 429) {
        final retryAt = _rateLimitRetryAt(error, attempts);
        await _replace(
          report.copyWith(
            status: QueuedStatus.rateLimited,
            message: error.userMessage,
            attempts: attempts,
            retryAtUtc: retryAt,
            event: 'Limité par le serveur : à renvoyer plus tard',
          ),
        );
        return _Outcome.rateLimited;
      }
      if (isOfflineError(error)) {
        await _replace(
          report.copyWith(
            attempts: attempts,
            clearRetryAt: true,
            event: 'Réseau indisponible, nouvel essai plus tard',
          ),
        );
        return _Outcome.offline;
      }
      await _replace(
        report.copyWith(
          status: QueuedStatus.rejected,
          message: errorMessage(error),
          attempts: attempts,
          event: 'Refusé par le serveur',
        ),
      );
    } on Exception catch (error) {
      if (isOfflineError(error)) {
        await _replace(
          report.copyWith(
            attempts: attempts,
            clearRetryAt: true,
            event: 'Réseau indisponible, nouvel essai plus tard',
          ),
        );
        return _Outcome.offline;
      }
      await _replace(
        report.copyWith(
          status: QueuedStatus.rejected,
          message: errorMessage(error),
          attempts: attempts,
          event: 'Refusé par le serveur',
        ),
      );
    }
    return _Outcome.needsUser;
  }

  static DateTime _rateLimitRetryAt(ApiException error, int attempts) {
    final fallbackSeconds = min(300, 5 * (1 << min(attempts - 1, 6)));
    final seconds = error.retryAfterSeconds ?? fallbackSeconds;
    return DateTime.now().toUtc().add(Duration(seconds: max(1, seconds)));
  }

  static String errorMessage(Object error) =>
      error is ApiException ? error.userMessage : 'Relevé refusé.';

  Future<void> _replace(QueuedReport report) =>
      _save([for (final item in state) item.id == report.id ? report : item]);

  Future<void> _remove(String id) async {
    await _store.deletePhoto(id);
    await _save([
      for (final item in state)
        if (item.id != id) item,
    ]);
  }

  /// The user confirms an unusual price: it is sent again as confirmed.
  Future<void> confirmUnusual(String id) async {
    final report = state.firstWhere((item) => item.id == id);
    if (report.ownerUserId != ref.read(activeAccountIdProvider)) {
      throw StateError('Only the report owner can confirm this report.');
    }
    await _replace(
      report.copyWith(
        status: QueuedStatus.pending,
        confirmOutlier: true,
        message: '',
        event: 'Prix confirmé par vous',
      ),
    );
    await sync();
  }

  /// The user gives up a report: their decision, never the app's.
  Future<void> discard(String id) async {
    final report = state.firstWhere((item) => item.id == id);
    if (report.ownerUserId != ref.read(activeAccountIdProvider)) {
      throw StateError('Only the report owner can discard this report.');
    }
    await _remove(id);
  }

  /// Empties the queue and its photos: called when the session ends, so a
  /// shared device keeps no position, note or photo of the previous account.
  Future<void> clearAll() async {
    await ready();
    for (final report in [...state]) {
      await _store.deletePhoto(report.id);
    }
    await _save(const []);
  }

  Future<void> discardUnassigned() async {
    final ids = state
        .where((report) => report.ownerUserId == null)
        .map((report) => report.id)
        .toList();
    for (final id in ids) {
      await _remove(id);
    }
  }
}

enum _Outcome {
  sent,
  offline,
  rateLimited,
  needsAuthentication,
  accountChanged,
  needsUser,
}
