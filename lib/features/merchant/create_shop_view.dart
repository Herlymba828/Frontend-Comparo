import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../identity/data/auth_providers.dart';
import 'merchant_repository.dart';

/// Opening a shop: grants the merchant role and opens the merchant space.
class CreateShopView extends ConsumerStatefulWidget {
  const CreateShopView({super.key});

  @override
  ConsumerState<CreateShopView> createState() => CreateShopViewState();
}

class CreateShopViewState extends ConsumerState<CreateShopView> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space24),
      children: [
        Text(
          'Ouvrir ma boutique',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.space8),
        const Text(
          'Publiez vos prix et vos stocks, recevez des commandes en livraison '
          'ou en retrait. La boutique est vérifiée par l’équipe avant d’être visible.',
        ),
        const SizedBox(height: AppSpacing.space16),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nom de la boutique'),
        ),
        TextField(
          controller: _description,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Téléphone'),
        ),
        const SizedBox(height: AppSpacing.space16),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: const Text('Créer ma boutique'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      showInfo(context, 'Donnez un nom à votre boutique.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(merchantRepositoryProvider)
          .createShop(
            name: _name.text.trim(),
            description: _description.text.trim(),
            phone: _phone.text.trim(),
          );
      // The merchant role was just granted: reload the profile and the shop.
      ref
        ..invalidate(authSessionProvider)
        ..invalidate(myShopProvider);
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'Boutique non créée.');
        setState(() => _saving = false);
      }
    }
  }
}
