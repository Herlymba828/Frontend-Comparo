import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_views.dart';
import 'merchant_repository.dart';

/// Catalog product search field (opens a search dialog).
class ProductPickerField extends ConsumerWidget {
  const ProductPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NamedRef? value;
  final ValueChanged<NamedRef> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(value?.name ?? 'Choisir un produit'),
      trailing: const Icon(Icons.search),
      onTap: () async {
        final picked = await showDialog<NamedRef>(
          context: context,
          builder: (context) => const _ProductSearchDialog(),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
    );
  }
}

class _ProductSearchDialog extends ConsumerStatefulWidget {
  const _ProductSearchDialog();

  @override
  ConsumerState<_ProductSearchDialog> createState() =>
      _ProductSearchDialogState();
}

class _ProductSearchDialogState extends ConsumerState<_ProductSearchDialog> {
  List<NamedRef> _results = const [];
  bool _loading = false;

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await ref
          .read(merchantRepositoryProvider)
          .searchProducts(query.trim());
      if (mounted) {
        setState(() => _results = results);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Produit'),
      content: SizedBox(
        width: 360,
        height: 360,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher…',
              ),
              onSubmitted: _search,
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: [
                  for (final product in _results)
                    ListTile(
                      title: Text(product.name),
                      onTap: () => Navigator.pop(context, product),
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
