import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';

class UserSessionInfo {
  const UserSessionInfo({
    required this.id,
    required this.device,
    required this.location,
    required this.lastActivity,
  });

  final String id;
  final String device;
  final String location;
  final DateTime? lastActivity;

  factory UserSessionInfo.fromJson(Map<String, dynamic> json) =>
      UserSessionInfo(
        id: json.requireString('id'),
        device: json.string('device_name', 'Appareil'),
        location: json.string('location'),
        lastActivity: json.dateOrNull('last_activity_at'),
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isUnread,
    required this.createdAt,
    required this.actionUrl,
  });

  final int id;
  final String title;
  final String body;
  final bool isUnread;
  final DateTime? createdAt;
  final String actionUrl;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json.requireInt('id'),
        title: json.string('title'),
        body: json.string('body'),
        isUnread: json.flag('is_unread'),
        createdAt: json.dateOrNull('created_at'),
        actionUrl: json.string('action_url'),
      );
}

class TicketMessage {
  const TicketMessage({
    required this.body,
    required this.fromSupport,
    required this.createdAt,
  });

  final String body;
  final bool fromSupport;
  final DateTime? createdAt;

  factory TicketMessage.fromJson(Map<String, dynamic> json) => TicketMessage(
    body: json.string('body'),
    fromSupport: json.string('author_type') != 'user',
    createdAt: json.dateOrNull('created_at'),
  );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.number,
    required this.subject,
    required this.category,
    required this.status,
    required this.isOpen,
    required this.updatedAt,
    this.messages = const [],
  });

  final int id;
  final String number;
  final String subject;
  final String category;
  final String status;
  final bool isOpen;
  final DateTime? updatedAt;
  final List<TicketMessage> messages;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json.requireInt('id'),
    number: json.string('ticket_number'),
    subject: json.string('subject'),
    category: json.string('category'),
    status: json.string('status', 'open'),
    isOpen: json.flag('is_open', true),
    updatedAt: json.dateOrNull('updated_at'),
    messages: json.maps('messages').map(TicketMessage.fromJson).toList(),
  );
}

/// French labels of the complaint types.
const complaintTypeLabels = {
  'wrong_price': 'Prix incorrect ou trompeur',
  'non_delivery': 'Commande non livrée',
  'damaged_goods': 'Produit endommagé / non conforme',
  'overcharge': 'Surfacturation',
  'refund_refused': 'Remboursement refusé',
  'merchant_conduct': 'Comportement d’un marchand',
  'counterfeit': 'Contrefaçon suspectée',
  'data_quality': 'Erreur dans le catalogue',
  'other': 'Autre',
};

class Complaint {
  const Complaint({
    required this.id,
    required this.number,
    required this.subject,
    required this.type,
    required this.status,
    required this.filedAt,
    this.isOpen = false,
    this.description = '',
    this.merchantResponse = '',
    this.respondedAt,
  });

  final int id;
  final String number;
  final String subject;
  final String type;
  final String status;
  final DateTime? filedAt;

  /// Still examined: it may be withdrawn.
  final bool isOpen;

  /// Detail only (empty in lists).
  final String description;
  final String merchantResponse;
  final DateTime? respondedAt;

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
    id: json.requireInt('id'),
    number: json.string('complaint_number'),
    subject: json.string('subject'),
    type: json.string('complaint_type'),
    status: json.string('status', 'filed'),
    filedAt: json.dateOrNull('filed_at'),
    isOpen: json.flag('is_open'),
    description: json.string('description'),
    merchantResponse: json.string('merchant_response'),
    respondedAt: json.dateOrNull('responded_at'),
  );
}

class Contribution {
  const Contribution({
    required this.id,
    required this.productName,
    required this.price,
    required this.currency,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.status,
    required this.observedAt,
    required this.confirmations,
    required this.rejections,
    required this.required,
    required this.rejectionReason,
    this.authorAlias = '',
    this.hasPhoto = false,
    this.photoPath = '',
    this.isPriceOutlier = false,
    this.displayError = false,
  });

  final int id;
  final String productName;
  final String price;
  final String currency;
  final String quantity;
  final String unit;
  final String location;
  final String status;
  final DateTime? observedAt;
  final int confirmations;
  final int rejections;
  final int required;
  final String rejectionReason;

  /// Pseudonym of the author (accounts are never shown to other users).
  final String authorAlias;
  final bool hasPhoto;

  /// API address of the photo (Bearer download), empty without photo.
  final String photoPath;
  final bool isPriceOutlier;
  final bool displayError;

  factory Contribution.fromJson(Map<String, dynamic> json) => Contribution(
    id: json.requireInt('id'),
    productName: json.string('raw_product_name', 'Produit'),
    price: json.string('observed_price', '0'),
    currency: json.string('currency', 'XAF'),
    quantity: json.string('quantity', '1'),
    // The symbol ("kg"), not the internal code ("pp-kg").
    unit: json.string('unit_symbol', json.string('unit_code')),
    location: json.string('location'),
    status: json.string('status', 'pending'),
    observedAt: json.dateOrNull('observed_at'),
    confirmations: json.intOrNull('confirmations_count') ?? 0,
    rejections: json.intOrNull('rejections_count') ?? 0,
    required: json.intOrNull('required_confirmations') ?? 0,
    rejectionReason: json.string('rejection_reason'),
    authorAlias: json.string('contributor_alias'),
    hasPhoto: json.flag('has_photo'),
    photoPath: json.string('photo'),
    isPriceOutlier: json.flag('is_price_outlier'),
    displayError: json.flag('display_error'),
  );
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(jsonApiProvider)),
);

final sessionsProvider = FutureProvider.autoDispose<List<UserSessionInfo>>(
  (ref) => ref.watch(accountRepositoryProvider).getSessions(),
);

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(accountRepositoryProvider).getNotifications(),
);

final ticketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(accountRepositoryProvider).getTickets(),
);

final ticketProvider = FutureProvider.autoDispose.family<SupportTicket, int>(
  (ref, id) => ref.watch(accountRepositoryProvider).getTicket(id),
);

final complaintsProvider = FutureProvider.autoDispose<List<Complaint>>(
  (ref) => ref.watch(accountRepositoryProvider).getComplaints(),
);

/// Mine ([toVerify] = false) or pending ones of other people to check.
final contributionsProvider = FutureProvider.autoDispose
    .family<List<Contribution>, bool>(
      (ref, toVerify) => ref
          .watch(accountRepositoryProvider)
          .getContributions(toVerify: toVerify),
    );

class AccountRepository {
  const AccountRepository(this._api);

  final JsonApi _api;

  // ── Profile & security ──────────────────────────────────────────────────
  Future<void> updateProfile({
    required String displayName,
    required String phone,
    required String city,
  }) => _api.patch(
    'api/auth/me/',
    (json) => json,
    data: {'display_name': displayName, 'phone': phone, 'city': city},
  );

  Future<void> changePassword({
    required String current,
    required String next,
    required String confirm,
  }) => _api.send(
    'api/auth/password/change/',
    data: {
      'current_password': current,
      'new_password': next,
      'new_password_confirm': confirm,
    },
  );

  Future<List<UserSessionInfo>> getSessions() =>
      _api.getAll('api/auth/sessions/', UserSessionInfo.fromJson);

  Future<void> revokeSession(String id) =>
      _api.delete('api/auth/sessions/$id/');

  /// E-mails a 6-digit code to the account's address.
  Future<void> sendEmailCode() => _api.send('api/auth/email/verify/');

  /// Confirms the address with the e-mailed code.
  Future<void> confirmEmail(String code) =>
      _api.send('api/auth/email/verify/confirm/', data: {'code': code.trim()});

  /// Closes the account (personal data erased, orders kept anonymously).
  Future<void> closeAccount(String password) =>
      _api.deleteWith('api/auth/me/', data: {'password': password});

  /// Photo of a report, downloaded with the session (never public).
  Future<List<int>> getReportPhoto(String path) => _api.getBytes(path);

  // ── Notifications ─────────────────────────────────────────────────────
  Future<List<AppNotification>> getNotifications() async => await _api.getAll(
    'api/notifications/',
    AppNotification.fromJson,
    query: {'channel': 'in_app'},
  );

  Future<void> markRead(int id) => _api.send('api/notifications/$id/read/');

  Future<void> markAllRead() => _api.send('api/notifications/read_all/');

  // ── Support & complaints ──────────────────────────────────────────────
  Future<List<SupportTicket>> getTickets() async =>
      await _api.getAll('api/support/tickets/', SupportTicket.fromJson);

  Future<SupportTicket> getTicket(int id) =>
      _api.getOne('api/support/tickets/$id/', SupportTicket.fromJson);

  Future<SupportTicket> openTicket({
    required String subject,
    required String body,
    required String category,
  }) => _api.post(
    'api/support/tickets/',
    SupportTicket.fromJson,
    data: {'subject': subject, 'body': body, 'category': category},
  );

  Future<void> replyTicket(int id, String body) =>
      _api.send('api/support/tickets/$id/reply/', data: {'body': body});

  Future<void> closeTicket(int id, {int? score}) => _api.send(
    'api/support/tickets/$id/close/',
    data: {'satisfaction_score': score},
  );

  /// A resolved or closed request comes back to the support team.
  Future<void> reopenTicket(int id) =>
      _api.send('api/support/tickets/$id/reopen/');

  Future<List<Complaint>> getComplaints() async => await _api.getAll(
    'api/disputes/',
    Complaint.fromJson,
    query: {'scope': 'filed'},
  );

  Future<void> fileComplaint({
    required String type,
    required String subject,
    required String description,
  }) => _api.send(
    'api/disputes/',
    data: {
      'complaint_type': type,
      'subject': subject,
      'description': description,
    },
  );

  Future<void> withdrawComplaint(int id) =>
      _api.send('api/disputes/$id/withdraw/');

  // ── Contributions ─────────────────────────────────────────────────────
  Future<List<Contribution>> getContributions({required bool toVerify}) async =>
      await _api.getAll(
        'api/contributions/',
        Contribution.fromJson,
        // 'mine': a moderator's own reports, not the whole moderation queue.
        query: toVerify ? {'to_verify': 1} : {'mine': 1},
      );

  Future<void> verifyContribution(
    int id, {
    required bool confirm,
    String comment = '',
  }) => _api.send(
    'api/contributions/$id/verify/',
    data: {'verdict': confirm ? 'confirm' : 'reject', 'comment': comment},
  );
}
