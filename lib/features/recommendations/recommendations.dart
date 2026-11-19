import 'package:comparo_ui/comparo_ui.dart' show SectionTitle;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/age_formatter.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/market_widgets.dart';
import '../commerce/commerce_repository.dart' show cartProvider;

/// One price behind a recommendation: the product, the shop, the amount and
/// when it was seen (BR-087/088: no recommendation without proof).
class RecommendationEvidence {
  const RecommendationEvidence({
    required this.role,
    required this.productName,
    required this.merchantName,
    required this.amount,
    required this.currency,
    required this.pack,
    required this.observedAt,
    required this.explanation,
  });

  /// `current_best` (the product looked at) or `recommended`.
  final String role;
  final String productName;
  final String merchantName;
  final String amount;
  final String currency;

  /// "5 kg".
  final String pack;
  final DateTime? observedAt;

  /// "Relevé il y a 2 h, vérifié par un modérateur."
  final String explanation;

  factory RecommendationEvidence.fromJson(Map<String, dynamic> json) =>
      RecommendationEvidence(
        role: json.requireString('role'),
        productName: json.requireString('product_name'),
        merchantName: json.requireString('merchant_name'),
        amount: json.requireString('amount'),
        currency: json.string('currency', 'XAF'),
        pack: '${json.string('quantity')} ${json.string('unit_symbol')}'.trim(),
        observedAt: json.dateOrNull('observed_at'),
        explanation: json.mapOrNull('trust')?.string('explanation') ?? '',
      );
}

/// A close substitute cheaper for the same quantity, at a verified shop
/// (`GET /api/recommendations/products/{id}/substitutes/`).
class SubstituteRecommendation {
  const SubstituteRecommendation({
    required this.id,
    required this.productId,
    required this.reason,
    required this.confidenceLabel,
    required this.freshnessLabel,
    required this.saving,
    required this.evidence,
  });

  final String id;
  final int productId;
  final String reason;
  final String confidenceLabel;
  final String freshnessLabel;

  /// Saved for the quantity of the product looked at, in XAF.
  final String saving;
  final List<RecommendationEvidence> evidence;

  RecommendationEvidence get recommended =>
      evidence.firstWhere((item) => item.role == 'recommended');

  factory SubstituteRecommendation.fromJson(Map<String, dynamic> json) {
    final evidence = json
        .maps('evidence')
        .map(RecommendationEvidence.fromJson)
        .toList();
    if (!evidence.any((item) => item.role == 'recommended')) {
      // No proof, no recommendation.
      throw const FormatException('Recommendation without evidence.');
    }
    final action = json.maps('actions').firstOrNull;
    return SubstituteRecommendation(
      id: json.requireString('id'),
      productId: action?.requireInt('product_id') ?? 0,
      reason: json.mapOrNull('reason')?.string('text') ?? '',
      confidenceLabel: json.mapOrNull('confidence')?.string('label') ?? '',
      freshnessLabel: json.mapOrNull('freshness')?.string('label') ?? '',
      saving: json.mapOrNull('saving')?.string('amount') ?? '0',
      evidence: evidence,
    );
  }
}

final substituteRecommendationsProvider = FutureProvider.autoDispose
    .family<List<SubstituteRecommendation>, int>((ref, productId) async {
      final page = await ref
          .watch(jsonApiProvider)
          .getOne(
            'api/recommendations/products/$productId/substitutes/',
            (json) => json,
          );
      return page
          .maps('results')
          .map(SubstituteRecommendation.fromJson)
          .toList();
    });

/// The best verified shop(s) for the active list
/// (`GET /api/recommendations/cart/`); null when there is not enough data.
class CartAdvice {
  const CartAdvice({
    required this.kind,
    required this.shopNames,
    required this.total,
    required this.reason,
  });

  /// `single` (one shop) or `split`.
  final String kind;
  final List<String> shopNames;
  final String total;
  final String reason;

  factory CartAdvice.fromJson(Map<String, dynamic> json) => CartAdvice(
    kind: json.requireString('kind'),
    shopNames: [
      for (final shop in json.maps('merchants')) shop.string('merchant_name'),
    ],
    total: json.requireString('total'),
    reason: json.mapOrNull('reason')?.string('text') ?? '',
  );
}

final cartAdviceProvider = FutureProvider.autoDispose<CartAdvice?>((ref) async {
  // A changed list is advised again.
  ref.watch(cartProvider);
  final answer = await ref
      .watch(jsonApiProvider)
      .getOne('api/recommendations/cart/', (json) => json);
  final recommended = answer.mapOrNull('recommended');
  return recommended == null ? null : CartAdvice.fromJson(recommended);
});

/// "Plus économique" on a product page. Optional: nothing is shown while
/// loading, on error, offline, or when no substitute is clearly cheaper.
/// Never the "meilleur prix" label: that belongs to the product's own offers.
class SubstituteRecommendationsSection extends ConsumerWidget {
  const SubstituteRecommendationsSection({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(substituteRecommendationsProvider(productId)).value;
    if (items == null || items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Plus économique'),
        const SizedBox(height: AppSpacing.space8),
        for (final item in items) ...[
          _SubstituteCard(item: item),
          const SizedBox(height: AppSpacing.space8),
        ],
      ],
    );
  }
}

class _SubstituteCard extends StatelessWidget {
  const _SubstituteCard({required this.item});

  final SubstituteRecommendation item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final offer = item.recommended;
    final age = offer.observedAt == null
        ? item.freshnessLabel
        : 'Relevé ${formatAge(offer.observedAt!)}';
    return Semantics(
      container: true,
      label:
          'Suggestion : ${offer.productName}, '
          '${formatPrice(offer.amount, offer.currency)} chez '
          '${offer.merchantName}, '
          '${formatPrice(item.saving, 'XAF')} de moins. $age. '
          '${item.confidenceLabel}.',
      child: MarketSurface(
        onTap: item.productId == 0
            ? null
            : () => context.push('/product/${item.productId}'),
        padding: const EdgeInsets.all(AppSpacing.space12),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(offer.productName, style: text.titleSmall),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Text(
                    formatPrice(offer.amount, offer.currency),
                    style: AppTextStyles.priceSecondary.copyWith(fontSize: 16),
                  ),
                ],
              ),
              Text(
                '${offer.pack} · ${offer.merchantName}',
                style: text.labelMedium,
              ),
              const SizedBox(height: AppSpacing.space4),
              StampBadge(
                label: '−${formatPrice(item.saving, 'XAF')}',
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(item.reason, style: text.bodyMedium),
              Text('$age · ${item.confidenceLabel}', style: text.labelMedium),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => showRecommendationEvidence(context, item),
                  child: const Text('Pourquoi ?'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Pourquoi cette suggestion ?": every price behind it, with its shop,
/// amount and when it was seen (BR-004).
Future<void> showRecommendationEvidence(
  BuildContext context,
  SubstituteRecommendation item,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          AppSpacing.space16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pourquoi cette suggestion ?', style: text.titleMedium),
            const SizedBox(height: AppSpacing.space8),
            Text(item.reason, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.space12),
            for (final evidence in item.evidence) ...[
              Text(
                evidence.role == 'recommended'
                    ? 'Suggéré : ${evidence.productName}'
                    : 'Comparé à : ${evidence.productName}',
                style: text.titleSmall,
              ),
              Text(
                '${formatPrice(evidence.amount, evidence.currency)} · '
                '${evidence.pack} · ${evidence.merchantName}',
                style: text.bodyMedium,
              ),
              if (evidence.explanation.isNotEmpty)
                Text(evidence.explanation, style: text.labelMedium),
              const SizedBox(height: AppSpacing.space12),
            ],
            Text(
              'Suggestion calculée sur des prix vérifiés de boutiques '
              'vérifiées. Aucune boutique ne paie pour y figurer.',
              style: text.labelMedium,
            ),
          ],
        ),
      ),
    );
  },
);

/// "Notre conseil" in Ma liste: the best verified shop(s) for the list, with
/// the reason. Hidden while loading, on error, or without enough data.
class CartAdviceCard extends ConsumerWidget {
  const CartAdviceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advice = ref.watch(cartAdviceProvider).value;
    if (advice == null) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final title = advice.kind == 'single'
        ? 'Tout chez ${advice.shopNames.first}'
        : 'Réparti dans ${advice.shopNames.length} boutiques';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space16),
      child: MarketSurface(
        onTap: () => context.push('/cart/optimise'),
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notre conseil', style: text.labelLarge),
            const SizedBox(height: AppSpacing.space4),
            Row(
              children: [
                Expanded(child: Text(title, style: text.titleMedium)),
                Text(
                  formatPrice(advice.total, 'XAF'),
                  style: AppTextStyles.priceSecondary.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(advice.reason, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
