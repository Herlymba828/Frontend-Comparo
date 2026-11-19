import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_views.dart';
import '../../core/widgets/space_scaffold.dart';
import 'create_shop_view.dart';
import 'merchant_repository.dart';

const merchantTabs = [
  SpaceTab(
    'Commandes',
    Icons.receipt_long_outlined,
    '/merchant/orders',
    selectedIcon: Icons.receipt_long,
  ),
  SpaceTab(
    'Offres',
    Icons.sell_outlined,
    '/merchant/offers',
    selectedIcon: Icons.sell,
  ),
  SpaceTab(
    'Stock',
    Icons.inventory_2_outlined,
    '/merchant/stock',
    selectedIcon: Icons.inventory_2,
  ),
  SpaceTab(
    'Réclamations',
    Icons.report_outlined,
    '/merchant/complaints',
    selectedIcon: Icons.report,
  ),
  SpaceTab(
    'Boutique',
    Icons.storefront_outlined,
    '/merchant/shop',
    selectedIcon: Icons.storefront,
  ),
];

/// Merchant space: the shop's tabs once it exists, the shop creation
/// before (opening a shop grants the merchant role).
class MerchantShell extends ConsumerWidget {
  const MerchantShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(myShopProvider);
    final current = shop.value;
    return SpaceScaffold(
      space: AppSpace.merchant,
      tabs: merchantTabs,
      location: location,
      showTabs: current != null,
      // Anyone signed in may open a shop: the role comes with it.
      roleGate: false,
      child: AsyncBody<Shop?>(
        value: shop,
        onRetry: () => ref.invalidate(myShopProvider),
        builder: (shop) => shop == null
            ? const CreateShopView()
            : CurrentShop(
                shop: shop,
                child: Column(
                  children: [
                    if (!shop.canPublish)
                      MaterialBanner(
                        content: Text(publishBlockedReason(shop)),
                        actions: const [SizedBox.shrink()],
                      ),
                    Expanded(child: child),
                  ],
                ),
              ),
      ),
    );
  }
}

/// The signed-in merchant's shop, for the tabs of the merchant space.
class CurrentShop extends InheritedWidget {
  const CurrentShop({super.key, required this.shop, required super.child});

  final Shop shop;

  static Shop? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrentShop>()?.shop;

  @override
  bool updateShouldNotify(CurrentShop oldWidget) => shop != oldWidget.shop;
}

/// Why [shop] cannot publish prices, offers or stock yet.
String publishBlockedReason(Shop shop) => !shop.isActive
    ? 'Boutique suspendue : la publication de prix, d’offres et de stock '
          'est impossible. Contactez l’aide pour en savoir plus.'
    : 'Boutique en attente de vérification par l’équipe : complétez vos '
          'justificatifs dans l’onglet Boutique. Vous pourrez publier vos '
          'prix, offres et stocks une fois votre boutique vérifiée.';

/// Whether the current shop may publish; false outside the merchant space.
bool shopCanPublish(BuildContext context) =>
    CurrentShop.maybeOf(context)?.canPublish ?? false;

/// Runs [action] when the current shop may publish, otherwise explains why
/// not instead of sending a request the API would refuse.
void whenShopCanPublish(BuildContext context, VoidCallback action) {
  final shop = CurrentShop.maybeOf(context);
  if (shop != null && shop.canPublish) {
    action();
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          shop == null
              ? 'Ouvrez d’abord votre boutique.'
              : publishBlockedReason(shop),
        ),
      ),
    );
}

/// A merchant "add" button, greyed while the shop cannot publish; a tap then
/// explains why.
class ShopActionButton extends StatelessWidget {
  const ShopActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = shopCanPublish(context);
    final colors = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      onPressed: () => whenShopCanPublish(context, onPressed),
      backgroundColor: enabled ? null : colors.surfaceContainerHighest,
      foregroundColor: enabled
          ? null
          : colors.onSurface.withValues(alpha: 0.38),
      tooltip: enabled
          ? null
          : 'Indisponible tant que la boutique n’est pas vérifiée',
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// A merchant tab built for the current shop (nothing outside the shell).
class ShopPage extends StatelessWidget {
  const ShopPage({super.key, required this.builder});

  final Widget Function(Shop shop) builder;

  @override
  Widget build(BuildContext context) {
    final shop = CurrentShop.maybeOf(context);
    return shop == null ? const SizedBox.shrink() : builder(shop);
  }
}
