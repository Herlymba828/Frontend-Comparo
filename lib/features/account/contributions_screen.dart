import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import 'account_repository.dart';
import 'email_verification_dialog.dart';
import 'report_photo_dialog.dart';

/// Field price reports: share one, follow mine, check other people's.
class ContributionsScreen extends ConsumerWidget {
  const ContributionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Relevés de prix'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'À vérifier'),
              Tab(text: 'Mes relevés'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/contributions/new'),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Relever un prix'),
        ),
        body: SignedInGate(
          signInMessage: 'Connectez-vous pour partager et vérifier des prix.',
          builder: (user) => const TabBarView(
            children: [
              _ContributionList(toVerify: true),
              _ContributionList(toVerify: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContributionList extends ConsumerStatefulWidget {
  const _ContributionList({required this.toVerify});

  final bool toVerify;

  @override
  ConsumerState<_ContributionList> createState() => _ContributionListState();
}

class _ContributionListState extends ConsumerState<_ContributionList> {
  final _busy = <int>{};

  Future<void> _verify(Contribution item, bool confirm) async {
    setState(() => _busy.add(item.id));
    try {
      await ref
          .read(accountRepositoryProvider)
          .verifyContribution(item.id, confirm: confirm);
      ref.invalidate(contributionsProvider(true));
      if (mounted) {
        showInfo(context, 'Merci pour votre vérification.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (isEmailNotVerified(error)) {
        // One person, several accounts: confirmations need a real address.
        setState(() => _busy.remove(item.id));
        if (await verifyEmailFlow(context, ref) && mounted) {
          await _verify(item, confirm);
        }
        return;
      }
      showApiError(context, error);
      // Already checked, no longer pending...: show the list as it is now.
      ref.invalidate(contributionsProvider(true));
    } finally {
      if (mounted) {
        setState(() => _busy.remove(item.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = contributionsProvider(widget.toVerify);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(provider),
      child: AsyncBody<List<Contribution>>(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        builder: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: widget.toVerify
                  ? Icons.fact_check_outlined
                  : Icons.add_a_photo_outlined,
              title: widget.toVerify
                  ? 'Rien à vérifier pour le moment.'
                  : 'Vous n’avez encore partagé aucun prix.',
              message: widget.toVerify
                  ? 'Les relevés des autres apparaissent ici : confirmez ceux '
                        'que vous avez vus vous aussi.'
                  : 'Un prix relevé en magasin aide toute la communauté.',
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space16,
              AppSpacing.space16,
              96,
            ),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.space8),
            itemBuilder: (context, index) {
              final item = items[index];
              return MarketSurface(
                padding: const EdgeInsets.all(AppSpacing.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        PriceTag(
                          label: formatPrice(item.price, item.currency),
                          caption:
                              '${formatQuantity(item.quantity)} ${item.unit}'
                                  .trim(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      [
                        if (item.location.isNotEmpty) item.location,
                        'relevé le ${formatDateTime(item.observedAt)}',
                        if (widget.toVerify && item.authorAlias.isNotEmpty)
                          'par ${item.authorAlias}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item.hasPhoto ||
                        item.isPriceOutlier ||
                        item.displayError)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.space4),
                        child: Wrap(
                          spacing: AppSpacing.space8,
                          runSpacing: AppSpacing.space4,
                          children: [
                            if (item.hasPhoto && item.photoPath.isNotEmpty)
                              ActionChip(
                                avatar: const Icon(
                                  Icons.photo_outlined,
                                  size: 18,
                                ),
                                label: const Text('Voir la photo'),
                                onPressed: () =>
                                    showReportPhoto(context, ref, item),
                              )
                            else if (item.hasPhoto)
                              const StampBadge(
                                label: 'PHOTO',
                                color: AppColors.primary,
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
                      ),
                    const SizedBox(height: AppSpacing.space8),
                    Row(
                      children: [
                        StatusStamp(item.status),
                        const SizedBox(width: AppSpacing.space8),
                        Expanded(
                          child: Text(
                            '${item.confirmations}/${item.required} confirmation(s)'
                            '${item.rejections == 0 ? '' : ' · ${item.rejections} contestation(s)'}',
                          ),
                        ),
                      ],
                    ),
                    if (item.rejectionReason.isNotEmpty)
                      Text('Motif : ${item.rejectionReason}'),
                    if (widget.toVerify)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _busy.contains(item.id)
                                ? null
                                : () => _verify(item, false),
                            icon: const Icon(Icons.thumb_down_outlined),
                            label: const Text('Contester'),
                          ),
                          FilledButton.icon(
                            onPressed: _busy.contains(item.id)
                                ? null
                                : () => _verify(item, true),
                            icon: const Icon(Icons.thumb_up_outlined),
                            label: const Text('J’ai vu ce prix'),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
