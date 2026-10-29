import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import '../../core/widgets/space_scaffold.dart';
import '../account/account_repository.dart';
import '../account/report_photo_dialog.dart';
import 'moderation_repository.dart';

const moderationTabs = [
  SpaceTab(
    'À décider',
    Icons.pending_actions_outlined,
    '/moderation/pending',
    selectedIcon: Icons.pending_actions,
  ),
  SpaceTab('Mes décisions', Icons.history, '/moderation/decided'),
];

/// Moderation space: reports to decide, and the moderator's decisions.
class ModerationShell extends StatelessWidget {
  const ModerationShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) => SpaceScaffold(
    space: AppSpace.moderation,
    tabs: moderationTabs,
    location: location,
    child: child,
  );
}

/// The queue: a report is published once enough people confirmed it.
class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  ConsumerState<ModerationQueueScreen> createState() =>
      _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen> {
  final _busy = <int>{};

  Future<void> _decide(Contribution item, String decision) async {
    var reason = '';
    if (decision != 'accepted') {
      final typed = await _askReason(decision);
      if (typed == null) {
        return;
      }
      reason = typed;
    }
    setState(() => _busy.add(item.id));
    try {
      await ref
          .read(moderationRepositoryProvider)
          .review(item.id, decision: decision, reason: reason);
      if (mounted) {
        showInfo(
          context,
          decision == 'accepted' ? 'Prix publié.' : 'Décision enregistrée.',
        );
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      // Decided here or by another moderator: the queue moves on.
      ref
        ..invalidate(moderationQueueProvider)
        ..invalidate(moderationDecisionsProvider);
      if (mounted) {
        setState(() => _busy.remove(item.id));
      }
    }
  }

  /// Reason shown to the contributor; null when cancelled.
  Future<String?> _askReason(String decision) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          decision == 'duplicate'
              ? 'Marquer comme doublon'
              : 'Refuser le relevé',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Motif (communiqué au contributeur)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (!(ok ?? false)) {
      return null;
    }
    if (text.isEmpty && mounted) {
      showInfo(context, 'Indiquez un motif.');
      return null;
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(moderationQueueProvider),
      child: AsyncBody<List<Contribution>>(
        value: ref.watch(moderationQueueProvider),
        onRetry: () => ref.invalidate(moderationQueueProvider),
        builder: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.task_alt,
                title: 'Aucun relevé en attente de décision.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final busy = _busy.contains(item.id);
                  return ReportCard(
                    item: item,
                    actions: [
                      FilledButton(
                        onPressed: busy || !isReadyToPublish(item)
                            ? null
                            : () => _decide(item, 'accepted'),
                        child: Text(reviewDecisionLabels['accepted']!),
                      ),
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => _decide(item, 'rejected'),
                        child: Text(reviewDecisionLabels['rejected']!),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => _decide(item, 'duplicate'),
                        child: Text(reviewDecisionLabels['duplicate']!),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// Same rule as the API: enough confirmations, and more than contestations.
bool isReadyToPublish(Contribution item) =>
    item.confirmations >= item.required && item.confirmations > item.rejections;

/// The reports this moderator decided.
class ModerationDecisionsScreen extends ConsumerWidget {
  const ModerationDecisionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(moderationDecisionsProvider),
      child: AsyncBody<List<Contribution>>(
        value: ref.watch(moderationDecisionsProvider),
        onRetry: () => ref.invalidate(moderationDecisionsProvider),
        builder: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.history,
                title: 'Vous n’avez encore décidé aucun relevé.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) =>
                    ReportCard(item: items[index], showStatus: true),
              ),
      ),
    );
  }
}

/// A field price report as a moderator examines it.
class ReportCard extends ConsumerWidget {
  const ReportCard({
    super.key,
    required this.item,
    this.actions = const [],
    this.showStatus = false,
  });

  final Contribution item;
  final List<Widget> actions;
  final bool showStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return MarketSurface(
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName, style: textTheme.titleSmall),
              ),
              PriceTag(
                label: formatPrice(item.price, item.currency),
                caption: '${formatQuantity(item.quantity)} ${item.unit}'.trim(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            [
              if (item.location.isNotEmpty) item.location,
              'relevé le ${formatDateTime(item.observedAt)}',
              if (item.authorAlias.isNotEmpty) 'par ${item.authorAlias}',
            ].join(' · '),
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            'Confirmations : ${item.confirmations} / ${item.required}'
            ' · contestations : ${item.rejections}',
            style: textTheme.bodySmall,
          ),
          Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space4,
            children: [
              if (showStatus) StatusStamp(item.status),
              if (item.hasPhoto && item.photoPath.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.photo_outlined, size: 18),
                  label: const Text('Voir la photo'),
                  onPressed: () => showReportPhoto(context, ref, item),
                ),
              if (item.isPriceOutlier)
                const StampBadge(
                  label: 'PRIX INHABITUEL',
                  color: AppColors.warning,
                ),
              if (item.displayError)
                const StampBadge(
                  label: 'ERREUR D’AFFICHAGE',
                  color: AppColors.terracotta,
                ),
            ],
          ),
          if (showStatus && item.rejectionReason.isNotEmpty)
            Text('Motif : ${item.rejectionReason}', style: textTheme.bodySmall),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space8),
            Wrap(
              spacing: AppSpacing.space8,
              runSpacing: AppSpacing.space4,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
