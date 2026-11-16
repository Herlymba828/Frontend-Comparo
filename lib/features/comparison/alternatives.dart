import 'package:comparo_ui/comparo_ui.dart' show SectionTitle;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/market_widgets.dart';
import '../catalog/models/catalog_product.dart';

/// A product that can replace the one on screen: a substitute, or an
/// equivalent that is not strict enough to be ranked with it
/// (`GET /api/comparison/products/{id}/alternatives/`).
class ProductAlternative {
  const ProductAlternative({
    required this.equivalenceId,
    required this.matchKind,
    required this.product,
    this.notes = '',
  });

  final int equivalenceId;

  /// `substitute`, or another kind of equivalence.
  final String matchKind;
  final String notes;
  final CatalogProduct product;

  bool get isSubstitute => matchKind == 'substitute';

  factory ProductAlternative.fromJson(Map<String, dynamic> json) {
    final product = json.mapOrNull('product');
    if (product == null) {
      throw const FormatException('Alternative without a product.');
    }
    return ProductAlternative(
      equivalenceId: json.requireInt('equivalence_id'),
      matchKind: json.string('match_kind'),
      notes: json.string('notes'),
      product: CatalogProduct.fromJson(product),
    );
  }
}

final productAlternativesProvider = FutureProvider.autoDispose
    .family<List<ProductAlternative>, int>(
      (ref, productId) => ref
          .watch(jsonApiProvider)
          .getAll(
            'api/comparison/products/$productId/alternatives/',
            ProductAlternative.fromJson,
          ),
    );

/// "Alternatives" under the offers of a product. Optional by nature: nothing
/// is shown while loading, on error, or when there is no alternative.
class AlternativesSection extends ConsumerWidget {
  const AlternativesSection({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(productAlternativesProvider(productId)).value;
    if (items == null || items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Alternatives'),
        const SizedBox(height: AppSpacing.space4),
        Text(
          'Des produits proches, pas comparés ci-dessus.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.space8),
        for (final alternative in items) ...[
          _AlternativeTile(alternative: alternative),
          const SizedBox(height: AppSpacing.space8),
        ],
      ],
    );
  }
}

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({required this.alternative});

  final ProductAlternative alternative;

  @override
  Widget build(BuildContext context) {
    final product = alternative.product;
    final hasPrice = (product.priceSnapshot ?? '').trim().isNotEmpty;
    final kind = alternative.isSubstitute
        ? 'Produit de substitution'
        : 'Produit équivalent';
    return MarketSurface(
      onTap: () => context.push('/product/${product.id}'),
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 48,
              child: ProductArtwork(
                url: product.imageUrl,
                name: product.name,
                unitSize: 48,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  alternative.notes.isEmpty
                      ? kind
                      : '$kind · ${alternative.notes}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space8),
          if (hasPrice)
            Text(
              formatPrice(product.priceSnapshot, product.priceSnapshotCurrency),
              style: AppTextStyles.priceSecondary.copyWith(fontSize: 16),
            ),
        ],
      ),
    );
  }
}
