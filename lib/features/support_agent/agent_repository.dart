import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../commerce/commerce_models.dart';

/// A complaint as the support team sees it (every complaint, with who filed
/// it and who handles it).
class AgentComplaint {
  const AgentComplaint({
    required this.id,
    required this.number,
    required this.subject,
    required this.type,
    required this.priority,
    required this.status,
    required this.isOpen,
    required this.filedAt,
    this.description = '',
    this.merchantResponse = '',
    this.filedById,
    this.assignedToId,
    this.resolutionOutcome,
    this.resolutionNotes = '',
    this.cashPayment,
  });

  final int id;
  final String number;
  final String subject;
  final String type;
  final String priority;
  final String status;
  final bool isOpen;
  final DateTime? filedAt;

  /// Detail only (empty in lists).
  final String description;
  final String merchantResponse;
  final int? filedById;
  final int? assignedToId;
  final String? resolutionOutcome;
  final String resolutionNotes;

  /// A cash dispute: the payment support has to rule on.
  final CashSummary? cashPayment;

  factory AgentComplaint.fromJson(Map<String, dynamic> json) {
    final resolution = json.mapOrNull('resolution');
    return AgentComplaint(
      id: json.requireInt('id'),
      number: json.string('complaint_number'),
      subject: json.string('subject'),
      type: json.string('complaint_type'),
      priority: json.string('priority', 'normal'),
      status: json.string('status', 'filed'),
      isOpen: json.flag('is_open'),
      filedAt: json.dateOrNull('filed_at'),
      description: json.string('description'),
      merchantResponse: json.string('merchant_response'),
      filedById: json.intOrNull('filed_by'),
      assignedToId: json.intOrNull('assigned_to'),
      resolutionOutcome: resolution?.stringOrNull('outcome'),
      resolutionNotes: resolution?.string('decision_notes') ?? '',
      cashPayment: CashSummary.fromJsonOrNull(json['cash_payment']),
    );
  }
}

class AgentTicketMessage {
  const AgentTicketMessage({
    required this.body,
    required this.authorType,
    required this.isInternal,
    required this.authorEmail,
    required this.createdAt,
  });

  final String body;
  final String authorType;

  /// A note only the team reads.
  final bool isInternal;
  final String authorEmail;
  final DateTime? createdAt;

  bool get fromCustomer => authorType == 'user';

  factory AgentTicketMessage.fromJson(Map<String, dynamic> json) =>
      AgentTicketMessage(
        body: json.string('body'),
        authorType: json.string('author_type'),
        isInternal: json.flag('is_internal'),
        authorEmail: json.string('author_email'),
        createdAt: json.dateOrNull('created_at'),
      );
}

class AgentTicket {
  const AgentTicket({
    required this.id,
    required this.number,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.isOpen,
    required this.updatedAt,
    this.assignedToId,
    this.messages = const [],
  });

  final int id;
  final String number;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final bool isOpen;
  final DateTime? updatedAt;
  final int? assignedToId;
  final List<AgentTicketMessage> messages;

  factory AgentTicket.fromJson(Map<String, dynamic> json) => AgentTicket(
    id: json.requireInt('id'),
    number: json.string('ticket_number'),
    subject: json.string('subject'),
    category: json.string('category'),
    priority: json.string('priority', 'normal'),
    status: json.string('status', 'open'),
    isOpen: json.flag('is_open', true),
    updatedAt: json.dateOrNull('updated_at'),
    assignedToId: json.intOrNull('assigned_to'),
    messages: json.maps('messages').map(AgentTicketMessage.fromJson).toList(),
  );
}

/// How a complaint is decided (the server's outcomes an agent can choose).
const complaintOutcomes = {
  'upheld': 'Réclamation fondée',
  'partially_upheld': 'Partiellement fondée',
  'rejected': 'Réclamation non fondée',
};

/// The remedies, with whether they need an amount.
const complaintRemedies = {
  'none': 'Aucun',
  'apology': 'Excuse formelle',
  'replacement': 'Remplacement du produit',
  'refund': 'Remboursement',
  'partial_refund': 'Remboursement partiel',
  'credit': 'Avoir',
};

/// Remedies the server requires an amount for (> 0).
const remediesWithAmount = {'refund', 'partial_refund', 'credit'};

const complaintPriorityLabels = {
  'low': 'Faible',
  'normal': 'Normale',
  'high': 'Élevée',
  'urgent': 'Urgente',
};

const complaintStatusLabels = {
  'filed': 'Déposée',
  'under_review': 'En examen',
  'pending_merchant': 'Attente marchand',
  'resolved': 'Résolue',
  'rejected': 'Rejetée',
  'escalated': 'Escaladée',
  'withdrawn': 'Retirée',
};

const ticketStatusLabels = {
  'open': 'Ouverte',
  'in_progress': 'En cours',
  'waiting_user': 'Attente client',
  'resolved': 'Résolue',
  'closed': 'Fermée',
};

final agentRepositoryProvider = Provider<AgentRepository>(
  (ref) => AgentRepository(ref.watch(jsonApiProvider)),
);

final agentComplaintsProvider = FutureProvider.autoDispose
    .family<List<AgentComplaint>, String?>(
      (ref, status) =>
          ref.watch(agentRepositoryProvider).complaints(status: status),
    );

final agentComplaintProvider = FutureProvider.autoDispose
    .family<AgentComplaint, int>(
      (ref, id) => ref.watch(agentRepositoryProvider).complaint(id),
    );

final agentTicketsProvider = FutureProvider.autoDispose
    .family<List<AgentTicket>, String?>(
      (ref, status) =>
          ref.watch(agentRepositoryProvider).tickets(status: status),
    );

final agentTicketProvider = FutureProvider.autoDispose.family<AgentTicket, int>(
  (ref, id) => ref.watch(agentRepositoryProvider).ticket(id),
);

class AgentRepository {
  const AgentRepository(this._api);

  final JsonApi _api;

  // ── Complaints ────────────────────────────────────────────────────────
  Future<List<AgentComplaint>> complaints({String? status}) => _api.getAll(
    'api/disputes/',
    AgentComplaint.fromJson,
    query: {'status': status},
  );

  Future<AgentComplaint> complaint(int id) =>
      _api.getOne('api/disputes/$id/', AgentComplaint.fromJson);

  Future<void> assignComplaint(int id, int agentId) =>
      _api.send('api/disputes/$id/assign/', data: {'agent_id': agentId});

  Future<void> waitForMerchant(int id) =>
      _api.send('api/disputes/$id/pending_merchant/');

  Future<void> decideComplaint(
    int id, {
    required String outcome,
    required String remedyType,
    required String notes,
    String? amount,
  }) => _api.send(
    'api/disputes/$id/resolve/',
    data: {
      'outcome': outcome,
      'remedy_type': remedyType,
      'remedy_amount': amount,
      'decision_notes': notes,
    },
  );

  /// Rules on a cash dispute: `collector_at_fault` (the money is deemed
  /// received, the usual presumption) or `payer_at_fault`.
  Future<void> arbitrateCash(
    String paymentNumber, {
    required String outcome,
    required String note,
  }) => _api.send(
    'api/payments/$paymentNumber/cash/arbitrate/',
    data: {'outcome': outcome, 'note': note},
  );

  // ── Tickets ───────────────────────────────────────────────────────────
  Future<List<AgentTicket>> tickets({String? status}) => _api.getAll(
    'api/support/tickets/',
    AgentTicket.fromJson,
    query: {'status': status},
  );

  Future<AgentTicket> ticket(int id) =>
      _api.getOne('api/support/tickets/$id/', AgentTicket.fromJson);

  Future<void> assignTicket(int id, int agentId) =>
      _api.send('api/support/tickets/$id/assign/', data: {'agent_id': agentId});

  Future<void> replyTicket(
    int id,
    String body, {
    bool internal = false,
    bool waitingForUser = false,
  }) => _api.send(
    'api/support/tickets/$id/reply/',
    data: {
      'body': body,
      'is_internal': internal,
      'waiting_for_user': waitingForUser,
    },
  );

  Future<void> resolveTicket(int id, {String note = ''}) =>
      _api.send('api/support/tickets/$id/resolve/', data: {'note': note});
}
