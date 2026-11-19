import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/space_scaffold.dart';
import '../account/account_repository.dart' show complaintTypeLabels;
import '../disputes/complaint_attachments.dart';
import '../identity/data/auth_providers.dart';
import '../moderation/moderation_review_screens.dart' show askNote;
import 'agent_repository.dart';

const supportTabs = [
  SpaceTab(
    'Réclamations',
    Icons.gavel_outlined,
    '/agent/complaints',
    selectedIcon: Icons.gavel,
  ),
  SpaceTab(
    'Demandes',
    Icons.support_agent_outlined,
    '/agent/tickets',
    selectedIcon: Icons.support_agent,
  ),
];

/// Support space: the complaints between customers and shops, and the help
/// requests. Reserved to the support role (and admins).
class SupportShell extends StatelessWidget {
  const SupportShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) => SpaceScaffold(
    space: AppSpace.support,
    tabs: supportTabs,
    location: location,
    child: child,
  );
}

/// The status filters of a list, then the list itself.
class _FilteredList extends StatelessWidget {
  const _FilteredList({
    required this.filters,
    required this.selected,
    required this.onSelected,
    required this.child,
  });

  final Map<String?, String> filters;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space8,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: AppSpacing.space8,
            children: [
              for (final entry in filters.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: selected == entry.key,
                  onSelected: (_) => onSelected(entry.key),
                ),
            ],
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}

String _assignment(int? assignedTo, int? me) => assignedTo == null
    ? 'Non assignée'
    : assignedTo == me
    ? 'Assignée à vous'
    : 'Assignée à un collègue';

// ── Complaints ───────────────────────────────────────────────────────────

class AgentComplaintsScreen extends ConsumerStatefulWidget {
  const AgentComplaintsScreen({super.key});

  @override
  ConsumerState<AgentComplaintsScreen> createState() =>
      _AgentComplaintsScreenState();
}

class _AgentComplaintsScreenState extends ConsumerState<AgentComplaintsScreen> {
  static const _filters = <String?, String>{
    null: 'Toutes',
    'filed': 'Déposées',
    'under_review': 'En examen',
    'pending_merchant': 'Attente marchand',
    'escalated': 'Escaladées',
  };

  String? _status;

  @override
  Widget build(BuildContext context) {
    final provider = agentComplaintsProvider(_status);
    final me = ref.watch(authSessionProvider).value?.id;
    return _FilteredList(
      filters: _filters,
      selected: _status,
      onSelected: (status) => setState(() => _status = status),
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(provider),
        child: AsyncBody<List<AgentComplaint>>(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (complaints) => complaints.isEmpty
              ? const EmptyState(
                  icon: Icons.gavel_outlined,
                  title: 'Aucune réclamation.',
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  itemCount: complaints.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.space8),
                  itemBuilder: (context, index) {
                    final complaint = complaints[index];
                    return Card(
                      child: ListTile(
                        title: Text(complaint.subject),
                        subtitle: Text(
                          '${complaint.number} · '
                          '${complaintTypeLabels[complaint.type] ?? complaint.type}\n'
                          '${_assignment(complaint.assignedToId, me)} · '
                          '${complaintPriorityLabels[complaint.priority] ?? complaint.priority}',
                        ),
                        isThreeLine: true,
                        trailing: StatusStamp(
                          complaint.status,
                          labels: complaintStatusLabels,
                        ),
                        onTap: () async {
                          await context.push(
                            '/agent/complaints/${complaint.id}',
                          );
                          ref.invalidate(provider);
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// One complaint: what happened, the shop's answer, and the agent's actions.
class AgentComplaintScreen extends ConsumerWidget {
  const AgentComplaintScreen({super.key, required this.complaintId});

  final int complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = agentComplaintProvider(complaintId);
    return Scaffold(
      appBar: AppBar(title: const Text('Réclamation')),
      body: SignedInGate(
        // isOpenTo, not a role: admins handle support as well.
        builder: (user) => !AppSpace.support.isOpenTo(user)
            ? const EmptyState(
                icon: Icons.block,
                title: 'Cet espace est réservé à un autre profil.',
              )
            : AsyncBody<AgentComplaint>(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                builder: (complaint) =>
                    _ComplaintBody(complaint: complaint, agentId: user.id),
              ),
      ),
    );
  }
}

class _ComplaintBody extends ConsumerStatefulWidget {
  const _ComplaintBody({required this.complaint, required this.agentId});

  final AgentComplaint complaint;
  final int agentId;

  @override
  ConsumerState<_ComplaintBody> createState() => _ComplaintBodyState();
}

class _ComplaintBodyState extends ConsumerState<_ComplaintBody> {
  bool _busy = false;

  AgentComplaint get _complaint => widget.complaint;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(agentComplaintProvider(_complaint.id))
        ..invalidate(agentComplaintsProvider);
      if (done != null && mounted) {
        showInfo(context, done);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _decide() async {
    final decision = await showDialog<_Decision>(
      context: context,
      builder: (context) => const _DecisionDialog(),
    );
    if (decision == null || !mounted) {
      return;
    }
    await _run(
      () => ref
          .read(agentRepositoryProvider)
          .decideComplaint(
            _complaint.id,
            outcome: decision.outcome,
            remedyType: decision.remedy,
            notes: decision.notes,
            amount: decision.amount,
          ),
      done: 'Décision enregistrée : le client et la boutique sont prévenus.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final complaint = _complaint;
    final text = Theme.of(context).textTheme;
    final mine = complaint.assignedToId == widget.agentId;
    // Nobody decides on their own complaint (the server refuses too).
    final own = complaint.filedById == widget.agentId;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        SectionCard(
          title: complaint.number,
          trailing: StatusStamp(
            complaint.status,
            labels: complaintStatusLabels,
          ),
          children: [
            InfoRow(
              'Motif',
              complaintTypeLabels[complaint.type] ?? complaint.type,
            ),
            InfoRow(
              'Priorité',
              complaintPriorityLabels[complaint.priority] ?? complaint.priority,
            ),
            InfoRow('Déposée le', formatDateTime(complaint.filedAt)),
            InfoRow(
              'Traitement',
              _assignment(complaint.assignedToId, widget.agentId),
            ),
            const Divider(),
            Text(complaint.subject, style: text.titleSmall),
            const SizedBox(height: AppSpacing.space4),
            Text(complaint.description),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        ComplaintAttachmentsCard(
          complaintId: complaint.id,
          isOpen: complaint.isOpen,
        ),
        if (complaint.merchantResponse.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space12),
          SectionCard(
            title: 'Réponse de la boutique',
            children: [Text(complaint.merchantResponse)],
          ),
        ],
        if (complaint.resolutionOutcome != null) ...[
          const SizedBox(height: AppSpacing.space12),
          SectionCard(
            title: 'Décision',
            children: [
              InfoRow(
                'Issue',
                complaintOutcomes[complaint.resolutionOutcome] ??
                    complaint.resolutionOutcome!,
              ),
              Text(complaint.resolutionNotes),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.space16),
        if (own && complaint.isOpen)
          Text(
            'C’est votre propre réclamation : un collègue doit la traiter.',
            style: text.bodySmall,
          ),
        if (!own && complaint.isOpen)
          Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space8,
            children: [
              if (!mine)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => ref
                              .read(agentRepositoryProvider)
                              .assignComplaint(complaint.id, widget.agentId),
                          done: 'Réclamation prise en charge.',
                        ),
                  child: const Text('Prendre en charge'),
                ),
              if (mine && complaint.status == 'under_review')
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => ref
                              .read(agentRepositoryProvider)
                              .waitForMerchant(complaint.id),
                          done: 'En attente de la réponse de la boutique.',
                        ),
                  child: const Text('Attendre la boutique'),
                ),
              if (mine)
                FilledButton(
                  onPressed: _busy ? null : _decide,
                  child: const Text('Trancher'),
                ),
            ],
          ),
      ],
    );
  }
}

typedef _Decision = ({
  String outcome,
  String remedy,
  String notes,
  String? amount,
});

/// The agent's decision: the outcome, the remedy (with its amount when it
/// has one) and the justification sent to the customer.
class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog();

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  String _outcome = 'upheld';
  String _remedy = 'apology';
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _rejected => _outcome == 'rejected';
  bool get _needsAmount => !_rejected && remediesWithAmount.contains(_remedy);

  /// A positive amount typed with a dot or a comma.
  String? get _parsedAmount {
    final value = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    return value != null && value > 0 ? value.toString() : null;
  }

  bool get _valid =>
      _notes.text.trim().isNotEmpty && (!_needsAmount || _parsedAmount != null);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Trancher la réclamation'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _outcome,
            decoration: const InputDecoration(labelText: 'Issue'),
            items: [
              for (final entry in complaintOutcomes.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _outcome = value ?? _outcome),
          ),
          if (!_rejected)
            DropdownButtonFormField<String>(
              initialValue: _remedy,
              decoration: const InputDecoration(labelText: 'Geste accordé'),
              items: [
                for (final entry in complaintRemedies.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _remedy = value ?? _remedy),
            ),
          if (_needsAmount)
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant',
                suffixText: 'FCFA',
              ),
              onChanged: (_) => setState(() {}),
            ),
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Explication (envoyée au client)',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _valid
            ? () => Navigator.pop(context, (
                outcome: _outcome,
                remedy: _rejected ? 'none' : _remedy,
                notes: _notes.text.trim(),
                amount: _needsAmount ? _parsedAmount : null,
              ))
            : null,
        child: const Text('Valider la décision'),
      ),
    ],
  );
}

// ── Tickets ──────────────────────────────────────────────────────────────

class AgentTicketsScreen extends ConsumerStatefulWidget {
  const AgentTicketsScreen({super.key});

  @override
  ConsumerState<AgentTicketsScreen> createState() => _AgentTicketsScreenState();
}

class _AgentTicketsScreenState extends ConsumerState<AgentTicketsScreen> {
  static const _filters = <String?, String>{
    null: 'Toutes',
    'open': 'Ouvertes',
    'in_progress': 'En cours',
    'waiting_user': 'Attente client',
    'resolved': 'Résolues',
  };

  String? _status;

  @override
  Widget build(BuildContext context) {
    final provider = agentTicketsProvider(_status);
    final me = ref.watch(authSessionProvider).value?.id;
    return _FilteredList(
      filters: _filters,
      selected: _status,
      onSelected: (status) => setState(() => _status = status),
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(provider),
        child: AsyncBody<List<AgentTicket>>(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (tickets) => tickets.isEmpty
              ? const EmptyState(
                  icon: Icons.support_agent_outlined,
                  title: 'Aucune demande.',
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  itemCount: tickets.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.space8),
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return Card(
                      child: ListTile(
                        title: Text(ticket.subject),
                        subtitle: Text(
                          '${ticket.number} · '
                          '${_assignment(ticket.assignedToId, me)}',
                        ),
                        trailing: StatusStamp(
                          ticket.status,
                          labels: ticketStatusLabels,
                        ),
                        onTap: () async {
                          await context.push('/agent/tickets/${ticket.id}');
                          ref.invalidate(provider);
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// One help request: the conversation (with the team's internal notes), a
/// reply bar, and the actions to take it in charge or mark it resolved.
class AgentTicketScreen extends ConsumerStatefulWidget {
  const AgentTicketScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  ConsumerState<AgentTicketScreen> createState() => _AgentTicketScreenState();
}

class _AgentTicketScreenState extends ConsumerState<AgentTicketScreen> {
  final _reply = TextEditingController();
  bool _internal = false;
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(agentTicketProvider(widget.ticketId))
        ..invalidate(agentTicketsProvider);
      if (done != null && mounted) {
        showInfo(context, done);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = agentTicketProvider(widget.ticketId);
    final repository = ref.read(agentRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Demande d’aide')),
      body: SignedInGate(
        builder: (user) => !AppSpace.support.isOpenTo(user)
            ? const EmptyState(
                icon: Icons.block,
                title: 'Cet espace est réservé à un autre profil.',
              )
            : AsyncBody<AgentTicket>(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                builder: (ticket) => Column(
                  children: [
                    ListTile(
                      title: Text(ticket.subject),
                      subtitle: Text(
                        '${ticket.number} · '
                        '${_assignment(ticket.assignedToId, user.id)}',
                      ),
                      trailing: StatusStamp(
                        ticket.status,
                        labels: ticketStatusLabels,
                      ),
                    ),
                    if (ticket.isOpen)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space16,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: AppSpacing.space8,
                            children: [
                              if (ticket.assignedToId != user.id)
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => repository.assignTicket(
                                            ticket.id,
                                            user.id,
                                          ),
                                          done: 'Demande prise en charge.',
                                        ),
                                  child: const Text('Prendre en charge'),
                                ),
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        final note = await askNote(
                                          context,
                                          title: 'Marquer comme résolue',
                                          label: 'Note de résolution',
                                        );
                                        if (note == null) {
                                          return;
                                        }
                                        await _run(
                                          () => repository.resolveTicket(
                                            ticket.id,
                                            note: note,
                                          ),
                                          done: 'Demande résolue.',
                                        );
                                      },
                                child: const Text('Marquer résolue'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.space16),
                        children: [
                          for (final message in ticket.messages)
                            _MessageBubble(message: message),
                        ],
                      ),
                    ),
                    if (ticket.isOpen)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.space8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _reply,
                                      minLines: 1,
                                      maxLines: 4,
                                      decoration: InputDecoration(
                                        hintText: _internal
                                            ? 'Note interne (invisible du client)…'
                                            : 'Réponse au client…',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Envoyer',
                                    icon: const Icon(Icons.send),
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            final body = _reply.text.trim();
                                            if (body.isEmpty) {
                                              return;
                                            }
                                            _run(() async {
                                              await repository.replyTicket(
                                                ticket.id,
                                                body,
                                                internal: _internal,
                                              );
                                              _reply.clear();
                                            });
                                          },
                                  ),
                                ],
                              ),
                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Note interne'),
                                subtitle: const Text(
                                  'Seule l’équipe la voit ; le client n’est pas prévenu.',
                                ),
                                value: _internal,
                                onChanged: (value) =>
                                    setState(() => _internal = value),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AgentTicketMessage message;

  @override
  Widget build(BuildContext context) {
    final fromCustomer = message.fromCustomer;
    return Align(
      alignment: fromCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: AppSpacing.space8),
        padding: const EdgeInsets.all(AppSpacing.space12),
        decoration: BoxDecoration(
          color: message.isInternal
              ? AppColors.warning.withValues(alpha: 0.15)
              : fromCustomer
              ? AppColors.surface
              : AppColors.kraft,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isInternal)
              Text(
                'NOTE INTERNE',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            Text(message.body),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '${fromCustomer ? 'Client' : 'Équipe'}'
              '${message.authorEmail.isEmpty ? '' : ' · ${message.authorEmail}'}'
              ' · ${formatDateTime(message.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
