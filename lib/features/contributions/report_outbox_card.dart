import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../identity/data/auth_providers.dart';
import 'report_outbox.dart';

const _statusLabels = {
  QueuedStatus.unassigned: 'Compte d’origine inconnu',
  QueuedStatus.pending: 'Non envoyé',
  QueuedStatus.needsAuthentication: 'Connexion au compte d’origine requise',
  QueuedStatus.rateLimited: 'Serveur occupé : renvoyez plus tard',
  QueuedStatus.needsConfirmation: 'Prix inhabituel : à confirmer',
  QueuedStatus.conflict: 'Déjà relevé par quelqu’un',
  QueuedStatus.rejected: 'Refusé',
};

/// Reports left on this device by an earlier version; shown only when there
/// are some. They leave only when the owner taps "Envoyer" (never by
/// themselves), and are deleted when the session ends.
class ReportOutboxCard extends ConsumerWidget {
  const ReportOutboxCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allReports = ref.watch(reportOutboxProvider);
    if (allReports.isEmpty) {
      return const SizedBox.shrink();
    }
    final accountId = ref.watch(activeAccountIdProvider);
    final reports = accountId == null
        ? const <QueuedReport>[]
        : allReports
              .where((report) => report.ownerUserId == accountId)
              .toList();
    final hasOtherAccountReports = allReports.any(
      (report) => report.ownerUserId != null && report.ownerUserId != accountId,
    );
    final hasUnassignedReports = allReports.any(
      (report) => report.ownerUserId == null,
    );
    final outbox = ref.read(reportOutboxProvider.notifier);
    final waiting = reports.where(
      (report) =>
          report.status == QueuedStatus.pending ||
          report.status == QueuedStatus.needsAuthentication ||
          report.status == QueuedStatus.rateLimited,
    );
    if (reports.isEmpty && !hasOtherAccountReports && !hasUnassignedReports) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space12,
        AppSpacing.space16,
        0,
      ),
      child: Column(
        children: [
          if (hasOtherAccountReports)
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text(
                'Certains relevés restent associés à un autre compte. '
                'Connectez-vous au compte d’origine pour les retrouver ; '
                'ils ne seront pas envoyés depuis cette session.',
              ),
            ),
          if (hasUnassignedReports)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(
                'Certains anciens relevés ne sont associés à aucun compte '
                'et ne seront pas envoyés.',
              ),
              trailing: TextButton(
                onPressed: () async {
                  if (await confirmAction(
                    context,
                    title: 'Supprimer les anciens relevés ?',
                    message:
                        'Le compte d’origine est inconnu. Ces relevés '
                        'ne peuvent pas être envoyés en sécurité.',
                    confirmLabel: 'Supprimer',
                  )) {
                    await outbox.discardUnassigned();
                  }
                },
                child: const Text('Supprimer'),
              ),
            ),
          if (reports.isNotEmpty)
            SectionCard(
              title: 'Mes relevés sur cet appareil (${reports.length})',
              trailing: waiting.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () async {
                        final sent = await outbox.sync();
                        if (context.mounted) {
                          showInfo(
                            context,
                            sent == 0
                                ? 'Aucun relevé envoyé. Vérifiez son statut '
                                      'et réessayez plus tard.'
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
                      '${report.productName} — '
                      '${formatPrice(report.price, 'XAF')}',
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
        ],
      ),
    );
  }
}
