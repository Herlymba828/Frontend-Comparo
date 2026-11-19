import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';

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

/// Asks a note; null when cancelled. [required] refuses an empty note.
Future<String?> askNote(
  BuildContext context, {
  required String title,
  required String label,
  bool required = false,
}) async {
  final note = await showDialog<String>(
    context: context,
    builder: (context) => _NoteDialog(title: title, label: label),
  );
  if (note != null && required && note.isEmpty && context.mounted) {
    showInfo(context, 'Indiquez un motif.');
    return null;
  }
  return note;
}

/// The dialog owns its text field: the controller lives as long as the
/// dialog, including its closing animation (disposing it right after
/// `showDialog` returns would leave the closing dialog using a dead one).
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 1000,
      maxLines: 3,
      decoration: InputDecoration(labelText: widget.label),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Valider'),
      ),
    ],
  );
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
