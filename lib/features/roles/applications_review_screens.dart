import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/files/protected_file.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/space_scaffold.dart';
import '../identity/data/auth_providers.dart';
import '../moderation/moderation_review_screens.dart' show askNote;
import 'roles_models.dart';
import 'roles_repository.dart';

const _roleFilters = {
  null: 'Toutes',
  'merchant': 'Marchands',
  'courier': 'Coursiers',
};

/// Applications waiting for a decision, oldest first. Never the reviewer's
/// own: nobody decides on their own application.
class ApplicationsQueueScreen extends ConsumerStatefulWidget {
  const ApplicationsQueueScreen({super.key});

  @override
  ConsumerState<ApplicationsQueueScreen> createState() =>
      _ApplicationsQueueScreenState();
}

class _ApplicationsQueueScreenState
    extends ConsumerState<ApplicationsQueueScreen> {
  String? _role;

  @override
  Widget build(BuildContext context) {
    final provider = applicationsToReviewProvider(_role);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space16,
            vertical: AppSpacing.space8,
          ),
          child: Wrap(
            spacing: AppSpacing.space8,
            children: [
              for (final entry in _roleFilters.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _role == entry.key,
                  onSelected: (_) => setState(() => _role = entry.key),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(provider),
            child: AsyncBody<List<RoleApplication>>(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              builder: (applications) => applications.isEmpty
                  ? const EmptyState(
                      icon: Icons.how_to_reg_outlined,
                      title: 'Aucune candidature à examiner.',
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.space16),
                      itemCount: applications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.space8),
                      itemBuilder: (context, index) {
                        final application = applications[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              application.shopName == null
                                  ? application.roleLabel
                                  : '${application.roleLabel} — '
                                        '${application.shopName}',
                            ),
                            subtitle: Text(
                              '${application.applicantName.isEmpty ? application.applicantEmail : application.applicantName}'
                              '\nEnvoyée le ${formatDateTime(application.submittedAt)}',
                            ),
                            isThreeLine: true,
                            trailing: StatusStamp(
                              application.status,
                              labels: roleStatusLabels,
                            ),
                            onTap: () async {
                              await context.push(
                                '/moderation/applications/${application.id}',
                              );
                              ref.invalidate(provider);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One application under review: the applicant, the answers, every document
/// (opened, accepted or refused one by one), then the decision.
class ApplicationReviewScreen extends ConsumerWidget {
  const ApplicationReviewScreen({super.key, required this.applicationId});

  final int applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = roleApplicationProvider(applicationId);
    return Scaffold(
      appBar: AppBar(title: const Text('Examen d’une candidature')),
      body: SignedInGate(
        // isOpenTo, not a role: admins review as well (same rule as the API).
        builder: (user) => !AppSpace.moderation.isOpenTo(user)
            ? const EmptyState(
                icon: Icons.block,
                title: 'Cet espace est réservé à un autre profil.',
              )
            : AsyncBody<RoleApplication>(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                builder: (application) =>
                    _ReviewBody(application: application, reviewerId: user.id),
              ),
      ),
    );
  }
}

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody({required this.application, required this.reviewerId});

  final RoleApplication application;
  final int reviewerId;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  bool _busy = false;

  RoleApplication get _application => widget.application;

  void _refresh() {
    ref
      ..invalidate(roleApplicationProvider(_application.id))
      ..invalidate(applicationsToReviewProvider);
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
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

  Future<void> _decideDocument(
    ApplicationDocument document, {
    required bool accepted,
  }) async {
    var reason = '';
    if (!accepted) {
      final typed = await askNote(
        context,
        title: 'Refuser ce justificatif',
        label: 'Pourquoi (communiqué au candidat)',
        required: true,
      );
      if (typed == null || !mounted) {
        return;
      }
      reason = typed;
    }
    await _run(
      () => ref
          .read(rolesRepositoryProvider)
          .decideDocument(
            _application.id,
            document.id,
            accepted: accepted,
            reason: reason,
          ),
    );
  }

  Future<void> _requestInfo() async {
    final message = await askNote(
      context,
      title: 'Demander un complément',
      label: 'Ce qui manque (envoyé au candidat)',
      required: true,
    );
    if (message == null || !mounted) {
      return;
    }
    await _run(
      () => ref
          .read(rolesRepositoryProvider)
          .requestInfo(_application.id, message),
      done: 'Le candidat est prévenu.',
    );
  }

  Future<void> _approve() async {
    final ok = await confirmAction(
      context,
      title: 'Accepter cette candidature ?',
      message: _application.role == 'merchant'
          ? 'La boutique sera vérifiée et le rôle marchand accordé.'
          : 'Le rôle ${_application.roleLabel.toLowerCase()} sera accordé.',
      confirmLabel: 'Accepter',
    );
    if (!ok || !mounted) {
      return;
    }
    await _run(
      () => ref.read(rolesRepositoryProvider).approve(_application.id),
      done: 'Candidature acceptée : le rôle est actif.',
    );
  }

  Future<void> _reject() async {
    final answer = await showDialog<({String reason, String message})>(
      context: context,
      builder: (context) => const _RejectionDialog(),
    );
    if (answer == null || !mounted) {
      return;
    }
    await _run(
      () => ref
          .read(rolesRepositoryProvider)
          .reject(
            _application.id,
            reason: answer.reason,
            message: answer.message,
          ),
      done: 'Candidature refusée : le candidat est prévenu.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final application = _application;
    final text = Theme.of(context).textTheme;
    // Nobody decides on their own application (the server refuses too).
    final ownApplication = application.applicantId == widget.reviewerId;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        SectionCard(
          title: application.shopName == null
              ? application.roleLabel
              : '${application.roleLabel} — ${application.shopName}',
          trailing: StatusStamp(application.status, labels: roleStatusLabels),
          children: [
            InfoRow(
              'Candidat',
              application.applicantName.isEmpty
                  ? application.applicantEmail
                  : application.applicantName,
            ),
            InfoRow('E-mail', application.applicantEmail),
            InfoRow(
              'Téléphone',
              application.applicantPhone.isEmpty
                  ? '—'
                  : application.applicantPhone,
            ),
            if (application.invited) const Text('Invité par l’équipe.'),
            InfoRow('Envoyée le', formatDateTime(application.submittedAt)),
            if (application.role == 'courier') ...[
              const Divider(),
              InfoRow('Transport', courierVehicles[application.vehicle] ?? '—'),
              InfoRow(
                'Téléphone déclaré',
                application.phone.isEmpty ? '—' : application.phone,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        SectionCard(
          title: 'Justificatifs',
          children: [
            Text(
              'Ouvrir un justificatif est journalisé. Acceptez ou refusez chacun : '
              'un justificatif refusé bloque l’acceptation du dossier.',
              style: text.bodySmall,
            ),
            for (final requirement in application.requirements)
              _ReviewDocumentTile(
                requirement: requirement,
                document: application.documentFor(requirement.kind),
                canDecide:
                    application.status == 'in_review' &&
                    !ownApplication &&
                    !_busy,
                onDecide: _decideDocument,
              ),
          ],
        ),
        if (application.reviewerMessage.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space12),
          SectionCard(
            title: 'Message envoyé au candidat',
            children: [Text(application.reviewerMessage)],
          ),
        ],
        const SizedBox(height: AppSpacing.space16),
        if (application.status == 'submitted')
          FilledButton(
            onPressed: _busy || ownApplication
                ? null
                : () => _run(
                    () => ref
                        .read(rolesRepositoryProvider)
                        .startReview(application.id),
                    done: 'Candidature prise en charge.',
                  ),
            child: const Text('Prendre en charge'),
          ),
        if (ownApplication && application.isUnderReview)
          Text(
            'C’est votre propre candidature : un autre membre de l’équipe '
            'doit la traiter.',
            style: text.bodySmall,
          ),
        if (application.status == 'in_review' && !ownApplication)
          Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _approve,
                child: const Text('Accepter'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _requestInfo,
                child: const Text('Demander un complément'),
              ),
              TextButton(
                onPressed: _busy ? null : _reject,
                child: const Text('Refuser'),
              ),
            ],
          ),
        if (!application.isUnderReview)
          Text(
            'Cette candidature est ${application.statusLabel.toLowerCase()} : '
            'plus aucune décision à prendre.',
            style: text.bodySmall,
          ),
      ],
    );
  }
}

class _ReviewDocumentTile extends ConsumerWidget {
  const _ReviewDocumentTile({
    required this.requirement,
    required this.document,
    required this.canDecide,
    required this.onDecide,
  });

  final RoleRequirement requirement;
  final ApplicationDocument? document;
  final bool canDecide;
  final Future<void> Function(ApplicationDocument, {required bool accepted})
  onDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = document;
    if (doc == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.radio_button_unchecked),
        title: Text(requirement.label),
        subtitle: Text(
          requirement.required ? 'Non envoyé' : 'Facultatif, non envoyé',
        ),
      );
    }
    final expires = doc.expiresOn;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: Text(requirement.label),
      subtitle: Text(
        [
          roleStatusLabels[doc.status] ?? doc.status,
          if (doc.isRejected && doc.rejectionReason.isNotEmpty)
            doc.rejectionReason,
          if (expires != null)
            'expire le ${expires.day.toString().padLeft(2, '0')}/'
                '${expires.month.toString().padLeft(2, '0')}/${expires.year}',
        ].join(' · '),
      ),
      onTap: () => openProtectedFile(
        context,
        ref,
        path: doc.downloadUrl,
        title: requirement.label,
      ),
      trailing: canDecide
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Accepter : ${requirement.label}',
                  icon: Icon(
                    Icons.check_circle_outline,
                    color: doc.isAccepted ? AppColors.primary : null,
                  ),
                  onPressed: () => onDecide(doc, accepted: true),
                ),
                IconButton(
                  tooltip: 'Refuser : ${requirement.label}',
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: doc.isRejected ? AppColors.terracotta : null,
                  ),
                  onPressed: () => onDecide(doc, accepted: false),
                ),
              ],
            )
          : const Icon(Icons.open_in_new),
    );
  }
}

/// The reason (from the server's list) and the explanation sent to the
/// applicant; both are required.
class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog();

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  String _reason = 'documents_invalid';
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Refuser la candidature'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _reason,
          decoration: const InputDecoration(labelText: 'Motif'),
          items: [
            for (final entry in rejectionReasons.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) => setState(() => _reason = value ?? _reason),
        ),
        TextField(
          controller: _message,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Explication (envoyée au candidat)',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _message.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                reason: _reason,
                message: _message.text.trim(),
              )),
        child: const Text('Refuser'),
      ),
    ],
  );
}

const _grantFilters = {
  null: 'Tous',
  'merchant': 'Marchands',
  'courier': 'Coursiers',
  'moderator': 'Modérateurs',
  'support': 'Support',
};

/// The roles held by other accounts: suspend, restore, revoke (admins), and
/// invite to a staff role (admins).
class RoleGrantsScreen extends ConsumerStatefulWidget {
  const RoleGrantsScreen({super.key});

  @override
  ConsumerState<RoleGrantsScreen> createState() => _RoleGrantsScreenState();
}

class _RoleGrantsScreenState extends ConsumerState<RoleGrantsScreen> {
  String? _role;
  bool _busy = false;

  Future<void> _change(RoleGrant grant, String action) async {
    final reason = await askNote(
      context,
      title: switch (action) {
        'suspend' => 'Suspendre ce rôle',
        'revoke' => 'Retirer ce rôle',
        _ => 'Rétablir ce rôle',
      },
      label: action == 'reactivate'
          ? 'Note (facultative)'
          : 'Motif (communiqué à la personne)',
      required: action != 'reactivate',
    );
    if (reason == null || !mounted) {
      return;
    }
    final repository = ref.read(rolesRepositoryProvider);
    setState(() => _busy = true);
    try {
      switch (action) {
        case 'suspend':
          await repository.suspend(grant.id, reason);
        case 'revoke':
          await repository.revoke(grant.id, reason);
        default:
          await repository.reactivate(grant.id, reason);
      }
      ref.invalidate(managedGrantsProvider);
      if (mounted) {
        showInfo(context, 'Rôle mis à jour : la personne est prévenue.');
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

  Future<void> _invite() async {
    final answer = await showDialog<({String email, String role})>(
      context: context,
      builder: (context) => const _InviteDialog(),
    );
    if (answer == null || !mounted) {
      return;
    }
    try {
      await ref
          .read(rolesRepositoryProvider)
          .invite(email: answer.email, role: answer.role);
      if (mounted) {
        showInfo(context, 'Invitation envoyée à ${answer.email}.');
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = managedGrantsProvider(_role);
    final isAdmin =
        ref.watch(authSessionProvider).value?.hasRole('admin') ?? false;
    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _invite,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Inviter'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space16,
              vertical: AppSpacing.space8,
            ),
            child: Wrap(
              spacing: AppSpacing.space8,
              children: [
                for (final entry in _grantFilters.entries)
                  // Staff roles are managed by admins only.
                  if (isAdmin ||
                      entry.key == null ||
                      entry.key == 'merchant' ||
                      entry.key == 'courier')
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _role == entry.key,
                      onSelected: (_) => setState(() => _role = entry.key),
                    ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(provider),
              child: AsyncBody<List<RoleGrant>>(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                builder: (grants) => grants.isEmpty
                    ? const EmptyState(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Aucun rôle à gérer.',
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.space16,
                          AppSpacing.space8,
                          AppSpacing.space16,
                          96,
                        ),
                        itemCount: grants.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.space8),
                        itemBuilder: (context, index) {
                          final grant = grants[index];
                          return Card(
                            child: ListTile(
                              title: Text(
                                grant.userName.isEmpty
                                    ? grant.userEmail
                                    : grant.userName,
                              ),
                              subtitle: Text(
                                [
                                  grant.roleLabel,
                                  grant.userEmail,
                                  if (!grant.isActive &&
                                      grant.statusReason.isNotEmpty)
                                    grant.statusReason,
                                ].join(' · '),
                              ),
                              isThreeLine:
                                  !grant.isActive &&
                                  grant.statusReason.isNotEmpty,
                              leading: StatusStamp(
                                grant.status,
                                labels: roleStatusLabels,
                              ),
                              trailing: grant.isRevoked
                                  ? null
                                  : PopupMenuButton<String>(
                                      tooltip: 'Gérer ce rôle',
                                      enabled: !_busy,
                                      onSelected: (action) =>
                                          _change(grant, action),
                                      itemBuilder: (context) => [
                                        if (grant.isActive)
                                          const PopupMenuItem(
                                            value: 'suspend',
                                            child: Text('Suspendre'),
                                          ),
                                        if (grant.isSuspended)
                                          const PopupMenuItem(
                                            value: 'reactivate',
                                            child: Text('Rétablir'),
                                          ),
                                        if (isAdmin)
                                          const PopupMenuItem(
                                            value: 'revoke',
                                            child: Text(
                                              'Retirer définitivement',
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  String _role = 'support';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Inviter à un rôle'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'La personne doit déjà avoir un compte. Elle envoie ensuite ses '
          'justificatifs, puis un autre membre de l’équipe valide.',
        ),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Adresse e-mail'),
          onChanged: (_) => setState(() {}),
        ),
        DropdownButtonFormField<String>(
          initialValue: _role,
          decoration: const InputDecoration(labelText: 'Rôle'),
          items: const [
            DropdownMenuItem(value: 'support', child: Text('Agent support')),
            DropdownMenuItem(value: 'moderator', child: Text('Modérateur')),
          ],
          onChanged: (value) => setState(() => _role = value ?? _role),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _valid
            ? () => Navigator.pop(context, (
                email: _email.text.trim(),
                role: _role,
              ))
            : null,
        child: const Text('Inviter'),
      ),
    ],
  );
}
