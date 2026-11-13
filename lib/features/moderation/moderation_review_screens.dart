import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files/protected_file.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import '../merchant/merchant_repository.dart' show ShopDocument;

/// A price far from its product's recent prices (PJ-020): a signal, not a
/// verdict.
class PriceAnomaly {
  const PriceAnomaly({
    required this.id,
    required this.productName,
    required this.merchantName,
    required this.type,
    required this.severity,
    required this.status,
    required this.rangeMin,
    required this.rangeMax,
    required this.ratio,
    required this.notes,
    required this.detectedAt,
  });

  final int id;
  final String productName;
  final String merchantName;
  final String type;
  final String severity;
  final String status;
  final String rangeMin;
  final String rangeMax;
  final String ratio;
  final String notes;
  final DateTime? detectedAt;

  bool get isOpen => status == 'open' || status == 'under_review';

  factory PriceAnomaly.fromJson(Map<String, dynamic> json) => PriceAnomaly(
    id: json.requireInt('id'),
    productName: json.string('product_name'),
    merchantName: json.string('merchant_name', 'Relevé'),
    type: json.string('anomaly_type'),
    severity: json.string('severity', 'medium'),
    status: json.string('status', 'open'),
    rangeMin: json.string('expected_range_min'),
    rangeMax: json.string('expected_range_max'),
    ratio: json.string('deviation_ratio'),
    notes: json.string('notes'),
    detectedAt: json.dateOrNull('detected_at'),
  );
}

const anomalyTypeLabels = {
  'price_spike': 'Pic de prix',
  'price_drop': 'Chute de prix',
  'outlier': 'Valeur aberrante',
  'stale_data': 'Données périmées',
  'duplicate': 'Doublon suspect',
  'pattern_break': 'Rupture de tendance',
  'context_conflict': 'Conflit de contexte',
  'user_report': 'Signalé par des consommateurs',
};

const severityLabels = {
  'low': 'Faible',
  'medium': 'Moyenne',
  'high': 'Élevée',
  'critical': 'Critique',
};

/// A shop waiting for verification (PJ-022).
class PendingShop {
  const PendingShop({
    required this.id,
    required this.name,
    required this.description,
    required this.phone,
    required this.email,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final String phone;
  final String email;
  final DateTime? createdAt;

  factory PendingShop.fromJson(Map<String, dynamic> json) => PendingShop(
    id: json.requireInt('id'),
    name: json.string('name'),
    description: json.string('description'),
    phone: json.string('phone'),
    email: json.string('email'),
    createdAt: json.dateOrNull('created_at'),
  );
}

final openAnomaliesProvider = FutureProvider.autoDispose<List<PriceAnomaly>>((
  ref,
) async {
  final api = ref.watch(jsonApiProvider);
  final all = await api.getAll(
    'api/quality/anomalies/',
    PriceAnomaly.fromJson,
    query: {'ordering': '-detected_at'},
  );
  return all.where((anomaly) => anomaly.isOpen).toList();
});

final shopsToVerifyProvider = FutureProvider.autoDispose<List<PendingShop>>(
  (ref) => ref
      .watch(jsonApiProvider)
      .getAll('api/merchants/to_verify/', PendingShop.fromJson),
);

/// The verification documents a shop sent (moderators only).
final pendingShopDocumentsProvider = FutureProvider.autoDispose
    .family<List<ShopDocument>, int>(
      (ref, shopId) => ref
          .watch(jsonApiProvider)
          .getAll('api/merchants/$shopId/documents/', ShopDocument.fromJson),
    );

/// Asks a note; null when cancelled. [required] refuses an empty note.
Future<String?> askNote(
  BuildContext context, {
  required String title,
  required String label,
  bool required = false,
}) async {
  final controller = TextEditingController();
  final note = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 1000,
        maxLines: 3,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Valider'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (note != null && required && note.isEmpty && context.mounted) {
    showInfo(context, 'Indiquez un motif.');
    return null;
  }
  return note;
}

class ModerationAnomaliesScreen extends ConsumerStatefulWidget {
  const ModerationAnomaliesScreen({super.key});

  @override
  ConsumerState<ModerationAnomaliesScreen> createState() =>
      _ModerationAnomaliesScreenState();
}

class _ModerationAnomaliesScreenState
    extends ConsumerState<ModerationAnomaliesScreen> {
  final _busy = <int>{};

  Future<void> _decide(PriceAnomaly anomaly, {required bool suspend}) async {
    final note = await askNote(
      context,
      title: suspend ? 'Suspendre le prix' : 'Garder le prix',
      label: suspend
          ? 'Pourquoi ce prix est faux'
          : 'Pourquoi ce prix est juste',
    );
    if (note == null || !mounted) {
      return;
    }
    setState(() => _busy.add(anomaly.id));
    try {
      await ref
          .read(jsonApiProvider)
          .send(
            'api/quality/anomalies/${anomaly.id}/'
            '${suspend ? 'resolve' : 'dismiss'}/',
            data: {'notes': note, if (suspend) 'suspend_price': true},
          );
      if (mounted) {
        showInfo(
          context,
          suspend ? 'Prix retiré de la comparaison.' : 'Prix conservé.',
        );
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      ref.invalidate(openAnomaliesProvider);
      if (mounted) {
        setState(() => _busy.remove(anomaly.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(openAnomaliesProvider),
      child: AsyncBody<List<PriceAnomaly>>(
        value: ref.watch(openAnomaliesProvider),
        onRetry: () => ref.invalidate(openAnomaliesProvider),
        builder: (anomalies) => anomalies.isEmpty
            ? const EmptyState(
                icon: Icons.verified_outlined,
                title: 'Aucune anomalie à examiner.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: anomalies.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) {
                  final anomaly = anomalies[index];
                  final busy = _busy.contains(anomaly.id);
                  return MarketSurface(
                    padding: const EdgeInsets.all(AppSpacing.space12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                anomaly.productName,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            StampBadge(
                              label:
                                  (severityLabels[anomaly.severity] ??
                                          anomaly.severity)
                                      .toUpperCase(),
                              color:
                                  anomaly.severity == 'high' ||
                                      anomaly.severity == 'critical'
                                  ? AppColors.terracotta
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                        Text(
                          '${anomalyTypeLabels[anomaly.type] ?? anomaly.type}'
                          ' · ${anomaly.merchantName}'
                          ' · ${formatDateTime(anomaly.detectedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (anomaly.rangeMin.isNotEmpty)
                          Text(
                            'Attendu entre ${formatPrice(anomaly.rangeMin, 'XAF')}'
                            ' et ${formatPrice(anomaly.rangeMax, 'XAF')}'
                            '${anomaly.ratio.isEmpty ? '' : ' (écart ×${anomaly.ratio})'}',
                          ),
                        if (anomaly.notes.isNotEmpty)
                          Text(
                            anomaly.notes,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: AppSpacing.space8),
                        Wrap(
                          spacing: AppSpacing.space8,
                          children: [
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => _decide(anomaly, suspend: false),
                              child: const Text('Garder le prix'),
                            ),
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => _decide(anomaly, suspend: true),
                              child: const Text('Suspendre le prix'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class ModerationShopsScreen extends ConsumerStatefulWidget {
  const ModerationShopsScreen({super.key});

  @override
  ConsumerState<ModerationShopsScreen> createState() =>
      _ModerationShopsScreenState();
}

class _ModerationShopsScreenState extends ConsumerState<ModerationShopsScreen> {
  final _busy = <int>{};

  Future<void> _decide(PendingShop shop, {required bool verify}) async {
    final documents = ref.read(pendingShopDocumentsProvider(shop.id)).value;
    if (verify && documents != null && documents.isEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Vérifier sans justificatif ?',
        message: '${shop.name} n’a envoyé aucun justificatif.',
        confirmLabel: 'Vérifier quand même',
      );
      if (!ok || !mounted) {
        return;
      }
    }
    String? reason;
    if (!verify) {
      reason = await askNote(
        context,
        title: 'Vérification à compléter',
        label: 'Ce qui manque (envoyé au marchand)',
        required: true,
      );
      if (reason == null || !mounted) {
        return;
      }
    }
    setState(() => _busy.add(shop.id));
    try {
      await ref
          .read(jsonApiProvider)
          .send(
            'api/merchants/${shop.id}/'
            '${verify ? 'verify' : 'reject_verification'}/',
            data: verify ? null : {'reason': reason},
          );
      if (mounted) {
        showInfo(
          context,
          verify ? 'Boutique vérifiée.' : 'Le marchand est prévenu.',
        );
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      ref.invalidate(shopsToVerifyProvider);
      if (mounted) {
        setState(() => _busy.remove(shop.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(shopsToVerifyProvider),
      child: AsyncBody<List<PendingShop>>(
        value: ref.watch(shopsToVerifyProvider),
        onRetry: () => ref.invalidate(shopsToVerifyProvider),
        builder: (shops) => shops.isEmpty
            ? const EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Aucune boutique à vérifier.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: shops.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) {
                  final shop = shops[index];
                  final busy = _busy.contains(shop.id);
                  return SectionCard(
                    title: shop.name,
                    children: [
                      if (shop.description.isNotEmpty) Text(shop.description),
                      InfoRow(
                        'Téléphone',
                        shop.phone.isEmpty ? '—' : shop.phone,
                      ),
                      InfoRow('E-mail', shop.email.isEmpty ? '—' : shop.email),
                      InfoRow('Ouverte le', formatDateTime(shop.createdAt)),
                      const Divider(),
                      _ShopDocuments(shop: shop),
                      const SizedBox(height: AppSpacing.space8),
                      Wrap(
                        spacing: AppSpacing.space8,
                        children: [
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _decide(shop, verify: false),
                            child: const Text('Demander un complément'),
                          ),
                          FilledButton(
                            onPressed: busy
                                ? null
                                : () => _decide(shop, verify: true),
                            child: const Text('Vérifier'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// The documents a shop sent for its verification, each one openable.
class _ShopDocuments extends ConsumerWidget {
  const _ShopDocuments({required this.shop});

  final PendingShop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = pendingShopDocumentsProvider(shop.id);
    return ref
        .watch(provider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Row(
            children: [
              Expanded(child: Text(errorText(error))),
              TextButton(
                onPressed: () => ref.invalidate(provider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
          data: (documents) => documents.isEmpty
              ? const Text('Aucun justificatif envoyé.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Justificatifs',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final document in documents)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(document.kindLabel),
                        subtitle: Text(
                          'Envoyé le ${formatDateTime(document.createdAt)}',
                        ),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => openProtectedFile(
                          context,
                          ref,
                          path: document.downloadUrl,
                          title: '${shop.name} — ${document.kindLabel}',
                        ),
                      ),
                  ],
                ),
        );
  }
}
