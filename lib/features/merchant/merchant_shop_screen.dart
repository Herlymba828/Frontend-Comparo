import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../commerce/commerce_repository.dart';
import '../stores/stores_repository.dart';
import 'merchant_repository.dart';

/// Shop settings and pickup locations.
class MerchantShopScreen extends ConsumerWidget {
  const MerchantShopScreen({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(shopLocationsProvider(shop.id));
    Future<void> act(Future<void> Function() action) async {
      try {
        await action();
        ref
          ..invalidate(shopLocationsProvider(shop.id))
          ..invalidate(myShopProvider);
      } catch (error) {
        if (context.mounted) {
          showApiError(context, error);
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        SectionCard(
          title: shop.name,
          trailing: StatusStamp(shop.isVerified ? 'verified' : 'pending'),
          children: [
            InfoRow(
              'Description',
              shop.description.isEmpty ? '—' : shop.description,
            ),
            InfoRow('Téléphone', shop.phone.isEmpty ? '—' : shop.phone),
            TextButton.icon(
              onPressed: () async {
                final values = await _editShop(context, shop);
                if (values != null) {
                  await act(
                    () => ref
                        .read(merchantRepositoryProvider)
                        .updateShop(
                          shop.id,
                          name: values.$1,
                          description: values.$2,
                          phone: values.$3,
                        ),
                  );
                }
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifier'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        SectionCard(
          title: 'Points de retrait',
          trailing: IconButton(
            tooltip: 'Ajouter un point de retrait',
            icon: const Icon(Icons.add_business_outlined),
            onPressed: () async {
              final values = await _newLocation(context);
              if (values != null) {
                await act(
                  () => ref
                      .read(merchantRepositoryProvider)
                      .addLocation(
                        shop.id,
                        name: values.name,
                        street: values.street,
                        city: values.city,
                        phone: values.phone,
                        latitude: values.latitude,
                        longitude: values.longitude,
                      ),
                );
              }
            },
          ),
          children: [
            locations.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text(errorText(error)),
              data: (items) => items.isEmpty
                  ? const Text(
                      'Ajoutez un point de retrait pour proposer le click & collect.',
                    )
                  : Column(
                      children: [
                        for (final location in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              location.isMain
                                  ? Icons.star
                                  : Icons.storefront_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(location.name),
                            subtitle: Text(
                              '${location.street} · ${location.city}'
                              '${location.isActive ? '' : ' · fermé'}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) => act(
                                () => value == 'main'
                                    ? ref
                                          .read(merchantRepositoryProvider)
                                          .setMainLocation(shop.id, location.id)
                                    : ref
                                          .read(merchantRepositoryProvider)
                                          .setLocationActive(
                                            shop.id,
                                            location.id,
                                            !location.isActive,
                                          ),
                              ),
                              itemBuilder: (context) => [
                                if (!location.isMain && location.isActive)
                                  const PopupMenuItem(
                                    value: 'main',
                                    child: Text('Point principal'),
                                  ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    location.isActive ? 'Fermer' : 'Rouvrir',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<(String, String, String)?> _editShop(BuildContext context, Shop shop) {
  final name = TextEditingController(text: shop.name);
  final description = TextEditingController(text: shop.description);
  final phone = TextEditingController(text: shop.phone);
  return showDialog<(String, String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ma boutique'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          TextField(
            controller: description,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            name.text.trim(),
            description.text.trim(),
            phone.text.trim(),
          )),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

typedef _NewLocation = ({
  String name,
  String street,
  String city,
  String phone,
  double? latitude,
  double? longitude,
});

Future<_NewLocation?> _newLocation(BuildContext context) {
  final name = TextEditingController();
  final street = TextEditingController();
  final city = TextEditingController(text: 'Libreville');
  final phone = TextEditingController();
  UserPosition? position;
  var locating = false;
  return showDialog<_NewLocation>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nouveau point de retrait'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              TextField(
                controller: street,
                decoration: const InputDecoration(labelText: 'Rue / quartier'),
              ),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: AppSpacing.space8),
              // On site, the device position places the store on the map:
              // shown "nearby" and usable for located price reports.
              OutlinedButton.icon(
                onPressed: locating
                    ? null
                    : () async {
                        setState(() => locating = true);
                        final found = await locateUser();
                        setState(() {
                          locating = false;
                          position = found;
                        });
                      },
                icon: const Icon(Icons.my_location),
                label: Text(
                  locating ? 'Localisation…' : 'Utiliser ma position',
                ),
              ),
              if (position != null)
                Text(
                  position!.isKnown
                      ? 'Position enregistrée (± '
                            '${(position!.accuracyM ?? 0).round()} m).'
                      : position!.problem ?? 'Position indisponible.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty || street.text.trim().isEmpty) {
                return;
              }
              Navigator.pop<_NewLocation>(context, (
                name: name.text.trim(),
                street: street.text.trim(),
                city: city.text.trim(),
                phone: phone.text.trim(),
                latitude: position?.latitude,
                longitude: position?.longitude,
              ));
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    ),
  );
}
