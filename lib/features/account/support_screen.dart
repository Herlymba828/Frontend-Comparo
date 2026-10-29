import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'account_repository.dart';

const _ticketCategories = {
  'order': 'Commande',
  'payment': 'Paiement',
  'delivery': 'Livraison',
  'product': 'Produit / prix',
  'account': 'Mon compte',
  'merchant': 'Un marchand',
  'technical': 'Problème technique',
  'other': 'Autre',
};

/// Support tickets (questions) and complaints (formal disputes).
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key, this.orderNumber});

  /// Prefills a new request about this order.
  final String? orderNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aide et réclamations'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mes demandes'),
              Tab(text: 'Réclamations'),
            ],
          ),
        ),
        body: SignedInGate(
          builder: (user) => TabBarView(
            children: [
              _TicketsTab(orderNumber: orderNumber),
              const _ComplaintsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketsTab extends ConsumerWidget {
  const _TicketsTab({this.orderNumber});

  final String? orderNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ticket = await showDialog<SupportTicket>(
            context: context,
            builder: (context) => _NewTicketDialog(orderNumber: orderNumber),
          );
          if (ticket != null) {
            ref.invalidate(ticketsProvider);
            if (context.mounted) {
              context.push('/support/tickets/${ticket.id}');
            }
          }
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nouvelle demande'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ticketsProvider),
        child: AsyncBody<List<SupportTicket>>(
          value: ref.watch(ticketsProvider),
          onRetry: () => ref.invalidate(ticketsProvider),
          builder: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.support_agent,
                  title: 'Aucune demande d’aide.',
                  message: 'Une question ? Écrivez-nous, nous répondons ici.',
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space16,
                    96,
                  ),
                  children: [
                    for (final ticket in items)
                      Card(
                        child: ListTile(
                          title: Text(ticket.subject),
                          subtitle: Text(
                            '${ticket.number} · ${_ticketCategories[ticket.category] ?? ticket.category}\n'
                            'Mis à jour le ${formatDateTime(ticket.updatedAt)}',
                          ),
                          isThreeLine: true,
                          trailing: StatusStamp(ticket.status),
                          onTap: () =>
                              context.push('/support/tickets/${ticket.id}'),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NewTicketDialog extends ConsumerStatefulWidget {
  const _NewTicketDialog({this.orderNumber});

  final String? orderNumber;

  @override
  ConsumerState<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends ConsumerState<_NewTicketDialog> {
  late String _category = widget.orderNumber == null ? 'other' : 'order';
  late final _subject = TextEditingController(
    text: widget.orderNumber == null ? '' : 'Commande ${widget.orderNumber}',
  );
  final _body = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle demande'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Sujet'),
              items: [
                for (final entry in _ticketCategories.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            TextField(
              controller: _body,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Votre message'),
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
          onPressed: _saving ? null : _send,
          child: const Text('Envoyer'),
        ),
      ],
    );
  }

  Future<void> _send() async {
    if (_subject.text.trim().isEmpty || _body.text.trim().isEmpty) {
      showInfo(context, 'Indiquez un titre et un message.');
      return;
    }
    setState(() => _saving = true);
    try {
      final ticket = await ref
          .read(accountRepositoryProvider)
          .openTicket(
            subject: _subject.text.trim(),
            body: _body.text.trim(),
            category: _category,
          );
      if (mounted) {
        Navigator.pop(context, ticket);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'Demande non envoyée.');
        setState(() => _saving = false);
      }
    }
  }
}

class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  final _reply = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(ticketProvider(widget.ticketId))
        ..invalidate(ticketsProvider);
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
    final repo = ref.read(accountRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ma demande')),
      body: SignedInGate(
        builder: (user) => AsyncBody<SupportTicket>(
          value: ref.watch(ticketProvider(widget.ticketId)),
          onRetry: () => ref.invalidate(ticketProvider(widget.ticketId)),
          builder: (ticket) => Column(
            children: [
              ListTile(
                title: Text(ticket.subject),
                subtitle: Text(ticket.number),
                trailing: StatusStamp(ticket.status),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  children: [
                    for (final message in ticket.messages)
                      Align(
                        alignment: message.fromSupport
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.only(
                            bottom: AppSpacing.space8,
                          ),
                          padding: const EdgeInsets.all(AppSpacing.space12),
                          decoration: BoxDecoration(
                            color: message.fromSupport
                                ? AppColors.kraft
                                : AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message.body),
                              const SizedBox(height: AppSpacing.space4),
                              Text(
                                '${message.fromSupport ? 'Support' : 'Vous'} · '
                                '${formatDateTime(message.createdAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (ticket.isOpen)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.space8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Votre réponse…',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Envoyer',
                          onPressed: _busy
                              ? null
                              : () {
                                  final text = _reply.text.trim();
                                  if (text.isEmpty) {
                                    return;
                                  }
                                  _run(() async {
                                    await repo.replyTicket(ticket.id, text);
                                    _reply.clear();
                                  });
                                },
                          icon: const Icon(Icons.send),
                        ),
                        PopupMenuButton<int>(
                          tooltip: 'Clore la demande',
                          icon: const Icon(Icons.check_circle_outline),
                          onSelected: (score) => _run(
                            () => repo.closeTicket(ticket.id, score: score),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              enabled: false,
                              child: Text('Problème réglé ? Notez-nous :'),
                            ),
                            for (var score = 5; score >= 1; score--)
                              PopupMenuItem(
                                value: score,
                                child: Text('★' * score),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (!ticket.isOpen)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.space8),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.space8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(() => repo.reopenTicket(ticket.id)),
                          icon: const Icon(Icons.replay),
                          label: const Text('Rouvrir'),
                        ),
                        if (ticket.status == 'resolved')
                          PopupMenuButton<int>(
                            tooltip: 'Clore et noter',
                            enabled: !_busy,
                            onSelected: (score) => _run(
                              () => repo.closeTicket(ticket.id, score: score),
                            ),
                            itemBuilder: (context) => [
                              for (var score = 5; score >= 1; score--)
                                PopupMenuItem(
                                  value: score,
                                  child: Text('★' * score),
                                ),
                            ],
                            child: const Chip(
                              avatar: Icon(Icons.star_outline, size: 18),
                              label: Text('Clore et noter'),
                            ),
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

class _ComplaintsTab extends ConsumerWidget {
  const _ComplaintsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(accountRepositoryProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final filed = await showDialog<bool>(
            context: context,
            builder: (context) => const _NewComplaintDialog(),
          );
          if (filed == true) {
            ref.invalidate(complaintsProvider);
          }
        },
        icon: const Icon(Icons.gavel_outlined),
        label: const Text('Déposer une réclamation'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(complaintsProvider),
        child: AsyncBody<List<Complaint>>(
          value: ref.watch(complaintsProvider),
          onRetry: () => ref.invalidate(complaintsProvider),
          builder: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.gavel_outlined,
                  title: 'Aucune réclamation.',
                  message:
                      'Prix trompeur, commande non livrée, remboursement refusé : '
                      'déposez une réclamation, l’équipe l’examine.',
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space16,
                    96,
                  ),
                  children: [
                    for (final complaint in items)
                      Card(
                        child: ListTile(
                          title: Text(complaint.subject),
                          subtitle: Text(
                            '${complaint.number} · '
                            '${complaintTypeLabels[complaint.type] ?? complaint.type}\n'
                            'Déposée le ${formatDateTime(complaint.filedAt)}'
                            '${complaint.isOpen ? '\nTouchez pour la retirer.' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: StatusStamp(complaint.status),
                          onTap: complaint.isOpen
                              ? () async {
                                  final ok = await confirmAction(
                                    context,
                                    title: 'Retirer la réclamation ?',
                                    message: 'Elle ne sera plus examinée.',
                                    confirmLabel: 'Retirer',
                                  );
                                  if (!ok) {
                                    return;
                                  }
                                  try {
                                    await repo.withdrawComplaint(complaint.id);
                                    ref.invalidate(complaintsProvider);
                                  } catch (error) {
                                    if (context.mounted) {
                                      showApiError(context, error);
                                    }
                                  }
                                }
                              : null,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NewComplaintDialog extends ConsumerStatefulWidget {
  const _NewComplaintDialog();

  @override
  ConsumerState<_NewComplaintDialog> createState() =>
      _NewComplaintDialogState();
}

class _NewComplaintDialogState extends ConsumerState<_NewComplaintDialog> {
  String _type = 'wrong_price';
  final _subject = TextEditingController();
  final _description = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle réclamation'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Motif'),
              items: [
                for (final entry in complaintTypeLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Que s’est-il passé ? (commande, date, marchand…)',
              ),
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
          onPressed: _saving ? null : _file,
          child: const Text('Déposer'),
        ),
      ],
    );
  }

  Future<void> _file() async {
    if (_subject.text.trim().isEmpty || _description.text.trim().isEmpty) {
      showInfo(context, 'Indiquez un titre et une description.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .fileComplaint(
            type: _type,
            subject: _subject.text.trim(),
            description: _description.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'Réclamation non déposée.');
        setState(() => _saving = false);
      }
    }
  }
}
