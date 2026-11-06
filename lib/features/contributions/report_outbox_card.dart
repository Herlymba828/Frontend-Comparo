import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'report_outbox.dart';

const _statusLabels = {
  QueuedStatus.pending: 'En attente du réseau',
  QueuedStatus.needsConfirmation: 'Prix inhabituel : à confirmer',
  QueuedStatus.conflict: 'Déjà relevé par quelqu’un',
  QueuedStatus.rejected: 'Refusé',
};

/// The reports kept on the phone; shown only when there are some.
class ReportOutboxCard extends ConsumerWidget {
  const ReportOutboxCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportOutboxProvider);
    if (reports.isEmpty) {
      return const SizedBox.shrink();
    }
    final outbox = ref.read(reportOutboxProvider.notifier);
    final waiting = reports.where((r) => r.status == QueuedStatus.pending);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space12,
        AppSpacing.space16,
        0,
      ),
      child: SectionCard(
        title: 'Sur ce téléphone (${reports.length})',
        trailing: waiting.isEmpty
            ? null
            : TextButton(
                onPressed: () async {
                  final sent = await outbox.sync();
                  if (context.mounted) {
                    showInfo(
                      context,
                      sent == 0
                          ? 'Toujours pas de réseau : nouvel essai plus tard.'
                          : '$sent relevé(s) envoyé(s).',
                    );
                  }
                },
                child: const Text('Envoyer'),
              ),
        children: [
          for (final report in reports)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${report.productName} — ${formatPrice(report.price, 'XAF')}',
              ),
              subtitle: Text(
                [
                  report.storeName,
                  formatDateTime(report.createdAt.toLocal()),
                  _statusLabels[report.status]!,
                  if (report.message.isNotEmpty) report.message,
                ].join(' · '),
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Que faire de ce relevé',
                onSelected: (action) async {
                  if (action == 'confirm') {
                    await outbox.confirmUnusual(report.id);
                  } else if (action == 'discard' &&
                      await confirmAction(
                        context,
                        title: 'Supprimer ce relevé ?',
                        message: 'Il ne sera jamais envoyé.',
                        confirmLabel: 'Supprimer',
                      )) {
                    await outbox.discard(report.id);
                  }
                },
                itemBuilder: (context) => [
                  if (report.status == QueuedStatus.needsConfirmation)
                    const PopupMenuItem(
                      value: 'confirm',
                      child: Text('Confirmer ce prix'),
                    ),
                  const PopupMenuItem(
                    value: 'discard',
                    child: Text('Supprimer'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
