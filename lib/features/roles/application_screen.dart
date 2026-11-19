import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files/protected_file.dart';
import '../../core/files/upload_file.dart';
import '../../core/files/upload_flow.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../identity/data/auth_providers.dart';
import 'roles_models.dart';
import 'roles_repository.dart';

/// The applicant's view of one application: what was asked, what is sent,
/// what the reviewer answered, and the way to send or withdraw it.
class ApplicationScreen extends ConsumerWidget {
  const ApplicationScreen({super.key, required this.applicationId});

  final int applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = roleApplicationProvider(applicationId);
    return Scaffold(
      appBar: AppBar(title: const Text('Ma candidature')),
      body: SignedInGate(
        builder: (user) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(provider),
          child: AsyncBody<RoleApplication>(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            builder: (application) => ApplicationBody(application: application),
          ),
        ),
      ),
    );
  }
}

class ApplicationBody extends ConsumerStatefulWidget {
  const ApplicationBody({super.key, required this.application});

  final RoleApplication application;

  @override
  ConsumerState<ApplicationBody> createState() => ApplicationBodyState();
}

class ApplicationBodyState extends ConsumerState<ApplicationBody> {
  bool _busy = false;

  RoleApplication get _application => widget.application;

  void _refresh() {
    ref
      ..invalidate(roleApplicationProvider(_application.id))
      ..invalidate(myRolesProvider);
  }

  /// Runs [action]; shows [done] when it worked, the API's message when not.
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

  Future<void> _upload(RoleRequirement requirement) async {
    DateTime? expiresOn;
    if (requirement.expiryRequired) {
      final today = DateTime.now();
      expiresOn = await showDatePicker(
        context: context,
        helpText: 'Date d’expiration — ${requirement.label}',
        initialDate: today.add(const Duration(days: 365)),
        firstDate: today.add(const Duration(days: 1)),
        lastDate: today.add(const Duration(days: 365 * 30)),
      );
      if (expiresOn == null || !mounted) {
        return;
      }
    }
    final sent = await pickAndSendUpload(
      context,
      allowPdf: true,
      maxBytes: documentMaxBytes,
      send: (file) => ref
          .read(rolesRepositoryProvider)
          .addDocument(
            _application.id,
            kind: requirement.kind,
            file: file,
            expiresOn: expiresOn,
          ),
    );
    if (sent) {
      _refresh();
      if (mounted) {
        showInfo(context, 'Justificatif envoyé.');
      }
    }
  }

  Future<void> _delete(ApplicationDocument document) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer ce justificatif ?',
      message: document.kindLabel,
      confirmLabel: 'Supprimer',
    );
    if (!ok || !mounted) {
      return;
    }
    await _run(
      () => ref
          .read(rolesRepositoryProvider)
          .deleteDocument(_application.id, document.id),
    );
  }

  Future<void> _withdraw() async {
    final ok = await confirmAction(
      context,
      title: 'Retirer ma candidature ?',
      message:
          'L’équipe ne l’examinera plus. Vous pourrez en déposer une autre.',
      confirmLabel: 'Retirer',
    );
    if (!ok || !mounted) {
      return;
    }
    await _run(
      () => ref.read(rolesRepositoryProvider).withdraw(_application.id),
      done: 'Candidature retirée.',
    );
  }

  Future<void> _submit() => _run(() async {
    await ref.read(rolesRepositoryProvider).submit(_application.id);
    // The role is granted by the decision: reload the session then.
    ref.invalidate(authSessionProvider);
  }, done: 'Candidature envoyée : vous serez prévenu de la décision.');

  @override
  Widget build(BuildContext context) {
    final application = _application;
    final text = Theme.of(context).textTheme;
    final ready =
        application.isEditable &&
        application.missing.isEmpty &&
        (application.role != 'courier' || application.vehicle.isNotEmpty);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        SectionCard(
          title: application.shopName == null
              ? application.roleLabel
              : '${application.roleLabel} — ${application.shopName}',
          trailing: StatusStamp(application.status, labels: roleStatusLabels),
          children: [
            if (application.invited)
              const Text(
                'Vous avez été invité par l’équipe à rejoindre ce rôle.',
              ),
            if (application.submittedAt != null)
              InfoRow('Envoyée le', formatDateTime(application.submittedAt)),
            Text(_statusHelp(application), style: text.bodySmall),
          ],
        ),
        if (application.reviewerMessage.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space12),
          SectionCard(
            title: application.isRejected
                ? 'Motif du refus : ${application.rejectionLabel}'
                : application.status == 'info_requested'
                ? 'À compléter'
                : 'Message de l’équipe',
            children: [Text(application.reviewerMessage)],
          ),
        ],
        if (application.role == 'courier') ...[
          const SizedBox(height: AppSpacing.space12),
          _CourierDetails(
            application: application,
            enabled: application.isEditable && !_busy,
            onSave: (details) => _run(
              () => ref
                  .read(rolesRepositoryProvider)
                  .updateDetails(application.id, details),
              done: 'Informations enregistrées.',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.space12),
        SectionCard(
          title: 'Justificatifs',
          children: [
            Text(
              'Photo ou PDF, 5 Mo au plus. Seuls vous et l’équipe qui examine '
              'votre dossier les voyez ; chaque consultation est journalisée.',
              style: text.bodySmall,
            ),
            for (final requirement in application.requirements)
              _RequirementTile(
                requirement: requirement,
                document: application.documentFor(requirement.kind),
                editable: application.isEditable && !_busy,
                onUpload: () => _upload(requirement),
                onDelete: _delete,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space16),
        if (application.isEditable) ...[
          if (!ready)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space8),
              child: Text(
                application.role == 'courier' && application.vehicle.isEmpty
                    ? 'Indiquez votre moyen de transport pour voir les '
                          'justificatifs à envoyer.'
                    : 'Il reste des justificatifs obligatoires à envoyer.',
                style: text.bodySmall,
              ),
            ),
          FilledButton(
            onPressed: ready && !_busy ? _submit : null,
            child: const Text('Envoyer ma candidature'),
          ),
        ],
        if (application.isOpen)
          TextButton(
            onPressed: _busy ? null : _withdraw,
            child: const Text('Retirer ma candidature'),
          ),
      ],
    );
  }

  static String _statusHelp(
    RoleApplication application,
  ) => switch (application.status) {
    'draft' =>
      'Brouillon : envoyez les justificatifs puis soumettez votre candidature.',
    'submitted' => 'Reçue : l’équipe va l’examiner.',
    'in_review' => 'L’équipe examine votre dossier.',
    'info_requested' =>
      'L’équipe demande un complément : corrigez puis renvoyez.',
    'approved' => 'Acceptée : le rôle est actif sur votre compte.',
    'rejected' => 'Refusée. Vous pourrez déposer un nouveau dossier plus tard.',
    'withdrawn' => 'Retirée.',
    _ => '',
  };
}

class _RequirementTile extends StatelessWidget {
  const _RequirementTile({
    required this.requirement,
    required this.document,
    required this.editable,
    required this.onUpload,
    required this.onDelete,
  });

  final RoleRequirement requirement;
  final ApplicationDocument? document;
  final bool editable;
  final VoidCallback onUpload;
  final Future<void> Function(ApplicationDocument document) onDelete;

  String get _state {
    final doc = document;
    if (doc == null) {
      return requirement.required ? 'À envoyer' : 'Facultatif';
    }
    if (doc.isRejected) {
      return 'Refusé : ${doc.rejectionReason}';
    }
    final sent = doc.isAccepted ? 'Accepté' : 'Envoyé';
    final expires = doc.expiresOn;
    return expires == null
        ? sent
        : '$sent · expire le ${expires.day.toString().padLeft(2, '0')}/'
              '${expires.month.toString().padLeft(2, '0')}/${expires.year}';
  }

  @override
  Widget build(BuildContext context) {
    final doc = document;
    final canReplace = editable && (doc == null || doc.isRejected);
    final canDelete = editable && doc != null && !doc.isAccepted;
    return Consumer(
      builder: (context, ref, child) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          doc == null
              ? Icons.radio_button_unchecked
              : doc.isRejected
              ? Icons.error_outline
              : Icons.check_circle_outline,
          color: doc == null
              ? null
              : doc.isRejected
              ? AppColors.terracotta
              : AppColors.primary,
        ),
        title: Text(requirement.label),
        subtitle: Text(
          [
            if (requirement.helpText.isNotEmpty) requirement.helpText,
            _state,
          ].join('\n'),
        ),
        isThreeLine: requirement.helpText.isNotEmpty,
        onTap: doc == null
            ? null
            : () => openProtectedFile(
                context,
                ref,
                path: doc.downloadUrl,
                title: requirement.label,
              ),
        trailing: canReplace
            ? IconButton(
                tooltip: 'Envoyer : ${requirement.label}',
                icon: const Icon(Icons.upload_file_outlined),
                onPressed: onUpload,
              )
            : canDelete
            ? IconButton(
                tooltip: 'Supprimer : ${requirement.label}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(doc),
              )
            : null,
      ),
    );
  }
}

/// A courier's answers: the vehicle decides which documents are asked.
class _CourierDetails extends StatefulWidget {
  const _CourierDetails({
    required this.application,
    required this.enabled,
    required this.onSave,
  });

  final RoleApplication application;
  final bool enabled;
  final Future<void> Function(Map<String, Object?> details) onSave;

  @override
  State<_CourierDetails> createState() => _CourierDetailsState();
}

class _CourierDetailsState extends State<_CourierDetails> {
  late String? _vehicle = widget.application.vehicle.isEmpty
      ? null
      : widget.application.vehicle;
  late final _phone = TextEditingController(text: widget.application.phone);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    if (!application.isEditable) {
      return SectionCard(
        title: 'Mes informations',
        children: [
          InfoRow('Transport', courierVehicles[application.vehicle] ?? '—'),
          InfoRow(
            'Téléphone',
            application.phone.isEmpty ? '—' : application.phone,
          ),
        ],
      );
    }
    return SectionCard(
      title: 'Mes informations',
      children: [
        DropdownButtonFormField<String>(
          initialValue: _vehicle,
          decoration: const InputDecoration(labelText: 'Moyen de transport'),
          items: [
            for (final entry in courierVehicles.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: widget.enabled
              ? (value) => setState(() => _vehicle = value)
              : null,
        ),
        TextField(
          controller: _phone,
          enabled: widget.enabled,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Téléphone',
            helperText: 'Format international, ex. +24101234567',
          ),
        ),
        const SizedBox(height: AppSpacing.space8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: widget.enabled && _vehicle != null
                ? () => widget.onSave({
                    'vehicle': _vehicle,
                    'phone': _phone.text.trim(),
                  })
                : null,
            child: const Text('Enregistrer'),
          ),
        ),
      ],
    );
  }
}
