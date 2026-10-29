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
      // No role check here: anyone signed in may open a shop.
      child: AsyncBody<Shop?>(
        value: shop,
        onRetry: () => ref.invalidate(myShopProvider),
        builder: (shop) => shop == null
            ? const CreateShopView()
            : CurrentShop(
                shop: shop,
                child: Column(
                  children: [
                    if (!shop.isVerified)
                      const MaterialBanner(
                        content: Text(
                          'Boutique en attente de vérification par l’équipe : '
                          'vos offres seront visibles une fois la boutique '
                          'vérifiée.',
                        ),
                        actions: [SizedBox.shrink()],
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
