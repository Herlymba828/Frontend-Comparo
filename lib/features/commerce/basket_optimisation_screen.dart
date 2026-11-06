import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'commerce_repository.dart';

typedef OptimisedLine = ({
  int productId,
  String productName,
  int offerId,
  int packs,
  String pack,
  String packPrice,
  String lineTotal,
});

class OptimisedMerchant {
  const OptimisedMerchant({
    required this.merchantId,
    required this.merchantName,
    required this.productsTotal,
    required this.deliveryFee,
    required this.lines,
  });

  final int merchantId;
  final String merchantName;
  final String productsTotal;
  final String deliveryFee;
  final List<OptimisedLine> lines;

  factory OptimisedMerchant.fromJson(Map<String, dynamic> json) =>
      OptimisedMerchant(
        merchantId: json.requireInt('merchant_id'),
        merchantName: json.string('merchant_name'),
        productsTotal: json.string('products_total', '0'),
        deliveryFee: json.string('delivery_fee', '0'),
        lines: [
          for (final line in json.maps('lines'))
            (
              productId: line.requireInt('product_id'),
              productName: line.string('product_name'),
              offerId: line.requireInt('offer_id'),
              packs: line.intOrNull('packs') ?? 1,
              pack: line.string('pack'),
              packPrice: line.string('pack_price'),
              lineTotal: line.string('line_total'),
            ),
        ],
      );
}

/// One way to buy the basket: at one merchant, or split between several.
class BasketSolution {
  const BasketSolution({
    required this.kind,
    required this.merchants,
    required this.productsTotal,
    required this.deliveryTotal,
    required this.paymentFees,
    required this.total,
  });

  final String kind;
  final List<OptimisedMerchant> merchants;
  final String productsTotal;
  final String deliveryTotal;
  final String paymentFees;
  final String total;

  bool get isSplit => kind == 'split';

  factory BasketSolution.fromJson(Map<String, dynamic> json) => BasketSolution(
    kind: json.string('kind', 'single'),
    merchants: json.maps('merchants').map(OptimisedMerchant.fromJson).toList(),
    productsTotal: json.string('products_total', '0'),
    deliveryTotal: json.string('delivery_total', '0'),
    paymentFees: json.string('payment_fees', '0'),
    total: json.string('total', '0'),
  );
}

class BasketOptimisation {
  const BasketOptimisation({
    required this.solutions,
    required this.unavailable,
    required this.withoutOffer,
  });

  final List<BasketSolution> solutions;
  final List<String> unavailable;
  final List<String> withoutOffer;

  factory BasketOptimisation.fromJson(Map<String, dynamic> json) =>
      BasketOptimisation(
        solutions: json.maps('solutions').map(BasketSolution.fromJson).toList(),
        unavailable: json.strings('unavailable'),
        withoutOffer: json.strings('without_offer'),
      );
}

final basketOptimisationProvider = FutureProvider.autoDispose
    .family<BasketOptimisation, bool>(
      (ref, delivery) => ref
          .watch(jsonApiProvider)
          .getOne(
            'api/cart/optimise/',
            BasketOptimisation.fromJson,
            query: {'delivery_mode': delivery ? 'delivery' : 'pickup'},
          ),
    );

/// Compares buying the cart at one merchant or split between merchants
/// (PJ-010); products, delivery and payment fees stay apart.
class BasketOptimisationScreen extends ConsumerStatefulWidget {
  const BasketOptimisationScreen({super.key});

  @override
  ConsumerState<BasketOptimisationScreen> createState() =>
      _BasketOptimisationScreenState();
}

class _BasketOptimisationScreenState
    extends ConsumerState<BasketOptimisationScreen> {
  bool _delivery = false;
  bool _busy = false;

  Future<void> _apply(OptimisedMerchant merchant, bool split) async {
    final ok = await confirmAction(
      context,
      title: 'Remplir le panier chez ${merchant.merchantName} ?',
      message: split
          ? 'Un panier ne contient qu’un marchand : votre panier actuel est '
                'remplacé par sa part. Revenez ici pour commander chez les '
                'autres ensuite.'
          : 'Votre panier actuel est remplacé par ces offres.',
      confirmLabel: 'Remplir le panier',
    );
    if (!ok) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(jsonApiProvider)
          .post(
            'api/cart/optimise/',
            (json) => json,
            data: {
              'merchant_id': merchant.merchantId,
              'lines': [
                for (final line in merchant.lines)
                  {'offer_id': line.offerId, 'packs': line.packs},
              ],
            },
          );
      ref
        ..invalidate(cartProvider)
        ..invalidate(basketOptimisationProvider);
      if (mounted) {
        showInfo(context, 'Panier rempli chez ${merchant.merchantName}.');
        Navigator.of(context).pop();
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
    final provider = basketOptimisationProvider(_delivery);
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer les marchands')),
      body: SignedInGate(
        builder: (user) => ListView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Retrait')),
                ButtonSegment(value: true, label: Text('Livraison')),
              ],
              selected: {_delivery},
              onSelectionChanged: (value) =>
                  setState(() => _delivery = value.first),
            ),
            const SizedBox(height: AppSpacing.space12),
            AsyncBody<BasketOptimisation>(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              builder: (result) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result.solutions.isEmpty)
                    const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Aucun marchand ne vend ces produits aujourd’hui.',
                    ),
                  for (final (index, solution) in result.solutions.indexed) ...[
                    _SolutionCard(
                      solution: solution,
                      best: index == 0,
                      enabled: !_busy,
                      onApply: (merchant) => _apply(merchant, solution.isSplit),
                    ),
                    const SizedBox(height: AppSpacing.space12),
                  ],
                  if (result.unavailable.isNotEmpty)
                    Text(
                      'Sans offre aujourd’hui : '
                      '${result.unavailable.join(', ')}.',
                    ),
                  if (result.withoutOffer.isNotEmpty)
                    Text(
                      'Ajoutés sans offre, non comparés : '
                      '${result.withoutOffer.join(', ')}.',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SolutionCard extends StatelessWidget {
  const _SolutionCard({
    required this.solution,
    required this.best,
    required this.enabled,
    required this.onApply,
  });

  final BasketSolution solution;
  final bool best;
  final bool enabled;
  final ValueChanged<OptimisedMerchant> onApply;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: solution.isSplit
          ? 'Répartir entre ${solution.merchants.length} marchands'
          : 'Tout chez ${solution.merchants.first.merchantName}',
      trailing: best
          ? Text('Le moins cher', style: Theme.of(context).textTheme.labelLarge)
          : null,
      children: [
        InfoRow('Produits', formatPrice(solution.productsTotal, 'XAF')),
        InfoRow('Livraison', formatPrice(solution.deliveryTotal, 'XAF')),
        InfoRow('Frais de paiement', formatPrice(solution.paymentFees, 'XAF')),
        InfoRow('Total', formatPrice(solution.total, 'XAF')),
        const Divider(),
        for (final merchant in solution.merchants) ...[
          Text(
            merchant.merchantName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final line in merchant.lines)
            InfoRow(
              '${line.packs} × ${line.pack}',
              '${line.productName} — ${formatPrice(line.lineTotal, 'XAF')}',
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: enabled ? () => onApply(merchant) : null,
              child: Text('Remplir le panier chez ${merchant.merchantName}'),
            ),
          ),
        ],
      ],
    );
  }
}
