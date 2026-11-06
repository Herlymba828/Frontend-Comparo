import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// From this width (Material's "expanded" size) the navigation moves to a
/// side rail: a bottom bar stretched over a desktop screen spreads its
/// destinations too far apart.
const wideLayoutBreakpoint = 840.0;

bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;

/// One destination of a navigation bar or rail.
class NavItem {
  const NavItem(this.label, this.icon, this.path, {this.selectedIcon});

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String path;
}

/// The bottom bar on phones, a side rail on wide screens, around [child].
class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.child,
    this.appBar,
    this.showNavigation = true,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final Widget child;
  final PreferredSizeWidget? appBar;

  /// False while the space is not set up yet (a merchant without shop).
  final bool showNavigation;

  void _go(BuildContext context, int index) {
    if (index != selectedIndex) {
      context.go(items[index].path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    if (!showNavigation) {
      return Scaffold(appBar: appBar, body: child);
    }
    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _go(context, index),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: item.selectedIcon == null
                        ? null
                        : Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(
              width: 1.5,
              thickness: 1.5,
              color: AppColors.ink,
            ),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.ink, width: 1.5)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _go(context, index),
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: item.selectedIcon == null
                    ? null
                    : Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Index of the item showing [location] (the longest matching path wins).
int navIndexFor(List<NavItem> items, String location) {
  var best = 0;
  var bestLength = -1;
  for (var i = 0; i < items.length; i++) {
    final path = items[i].path;
    final matches =
        location == path || (path != '/' && location.startsWith('$path/'));
    if (matches && path.length > bestLength) {
      best = i;
      bestLength = path.length;
    }
  }
  return best;
}

const customerTabs = [
  NavItem('Accueil', Icons.home_outlined, '/', selectedIcon: Icons.home),
  NavItem('Recherche', Icons.search, '/search'),
  NavItem(
    'Panier',
    Icons.shopping_basket_outlined,
    '/cart',
    selectedIcon: Icons.shopping_basket,
  ),
  NavItem(
    'Compte',
    Icons.person_outline,
    '/account',
    selectedIcon: Icons.person,
  ),
];

/// The customer space's four tabs; the screens bring their own app bar.
class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) => AdaptiveNavigation(
    items: customerTabs,
    selectedIndex: navIndexFor(customerTabs, location),
    child: child,
  );
}
