import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../disputes/complaint_attachments.dart';
import 'account_repository.dart';

/// One complaint filed by the customer: its evidence, the shop's answer,
/// and withdrawal while it is examined.
class ComplaintScreen extends ConsumerWidget {
  const ComplaintScreen({super.key, required this.complaintId});

  final int complaintId;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
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
      await ref.read(accountRepositoryProvider).withdrawComplaint(complaintId);
      ref
        ..invalidate(complaintProvider(complaintId))
        ..invalidate(complaintsProvider);
    } catch (error) {
      if (context.mounted) {
        showApiError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = complaintProvider(complaintId);
    return Scaffold(
      appBar: AppBar(title: const Text('Réclamation')),
      body: SignedInGate(
        builder: (user) => AsyncBody<Complaint>(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (complaint) => ListView(
            padding: const EdgeInsets.all(AppSpacing.space16),
            children: [
              SectionCard(
                title: complaint.number,
                trailing: StatusStamp(complaint.status),
                children: [
                  InfoRow(
                    'Motif',
                    complaintTypeLabels[complaint.type] ?? complaint.type,
                  ),
                  InfoRow('Déposée le', formatDateTime(complaint.filedAt)),
                  const Divider(),
                  Text(
                    complaint.subject,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
                  title: 'Réponse du marchand',
                  children: [
                    Text(complaint.merchantResponse),
                    if (complaint.respondedAt != null)
                      Text(
                        'Le ${formatDateTime(complaint.respondedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
              if (complaint.isOpen) ...[
                const SizedBox(height: AppSpacing.space24),
                OutlinedButton.icon(
                  onPressed: () => _withdraw(context, ref),
                  icon: const Icon(Icons.undo),
                  label: const Text('Retirer la réclamation'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
