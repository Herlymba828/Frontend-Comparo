import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import '../account/account_repository.dart';
import 'merchant_repository.dart';

/// Complaints filed against the shop (the ones the merchant filed as a
/// customer stay in the customer space).
class MerchantComplaintsScreen extends ConsumerWidget {
  const MerchantComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(receivedComplaintsProvider),
      child: AsyncBody<List<Complaint>>(
        value: ref.watch(receivedComplaintsProvider),
        onRetry: () => ref.invalidate(receivedComplaintsProvider),
        builder: (complaints) => complaints.isEmpty
            ? const EmptyState(
                icon: Icons.verified_outlined,
                title: 'Aucune réclamation contre votre boutique.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: complaints.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) {
                  final complaint = complaints[index];
                  return MarketSurface(
                    onTap: () =>
                        context.push('/merchant/complaints/${complaint.id}'),
                    padding: const EdgeInsets.all(AppSpacing.space12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.subject,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                '${complaintTypeLabels[complaint.type] ?? complaint.type}'
                                ' · ${formatDateTime(complaint.filedAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        StatusStamp(complaint.status),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// One complaint against the shop, with the shop's answer.
class MerchantComplaintScreen extends ConsumerStatefulWidget {
  const MerchantComplaintScreen({super.key, required this.complaintId});

  final int complaintId;

  @override
  ConsumerState<MerchantComplaintScreen> createState() =>
      _MerchantComplaintScreenState();
}

class _MerchantComplaintScreenState
    extends ConsumerState<MerchantComplaintScreen> {
  final _response = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _response.text.trim();
    if (text.isEmpty) {
      showInfo(context, 'Écrivez votre réponse.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(merchantRepositoryProvider)
          .respondToComplaint(widget.complaintId, text);
      _response.clear();
      ref
        ..invalidate(receivedComplaintProvider(widget.complaintId))
        ..invalidate(receivedComplaintsProvider);
      if (mounted) {
        showInfo(context, 'Réponse transmise au service client.');
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
    final provider = receivedComplaintProvider(widget.complaintId);
    return Scaffold(
      appBar: AppBar(title: const Text('Réclamation')),
      body: SignedInGate(
        role: 'merchant',
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
              SectionCard(
                title: 'Votre réponse',
                children: [
                  if (complaint.merchantResponse.isNotEmpty) ...[
                    Text(complaint.merchantResponse),
                    if (complaint.respondedAt != null)
                      Text(
                        'Envoyée le ${formatDateTime(complaint.respondedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ] else if (!complaint.isOpen)
                    const Text('Aucune réponse : la réclamation est close.'),
                  if (complaint.isOpen) ...[
                    const SizedBox(height: AppSpacing.space8),
                    TextField(
                      controller: _response,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        labelText: complaint.merchantResponse.isEmpty
                            ? 'Votre version des faits'
                            : 'Compléter ou corriger votre réponse',
                      ),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _send,
                      child: const Text('Envoyer au service client'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
