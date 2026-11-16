import 'package:comparo_ui/comparo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/commerce/commerce_repository.dart';
import '../../features/identity/data/auth_providers.dart';

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
    this.badges = const {},
  });

  final List<NavItem> items;
  final int selectedIndex;
  final Widget child;

  /// Compteur par position d'onglet (articles de « Ma liste »).
  final Map<int, int> badges;
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
                for (final (index, item) in items.indexed)
                  NavigationRailDestination(
                    icon: Badge(
                      isLabelVisible: (badges[index] ?? 0) > 0,
                      label: Text('${badges[index]}'),
                      child: Icon(item.icon),
                    ),
                    selectedIcon: item.selectedIcon == null
                        ? null
                        : Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: child,
      bottomNavigationBar: ComparoNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => _go(context, index),
        items: [
          for (final (index, item) in items.indexed)
            ComparoNavItem(
              icon: item.icon,
              label: item.label,
              badge: (badges[index] ?? 0) > 0 ? badges[index] : null,
            ),
        ],
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
  NavItem('Recherche', Icons.search_rounded, '/search'),
  NavItem(
    'Ma liste',
    Icons.checklist_rounded,
    '/cart',
    selectedIcon: Icons.checklist_rounded,
  ),
  NavItem(
    'Profil',
    Icons.person_outline_rounded,
    '/account',
    selectedIcon: Icons.person_rounded,
  ),
];

/// Position de « Ma liste » dans [customerTabs].
const _listTabIndex = 2;

/// The customer space's four tabs; the screens bring their own app bar.
class CustomerShell extends ConsumerWidget {
  const CustomerShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The list count is only asked for a signed-in user: a visitor has no cart.
    final signedIn = ref.watch(authSessionProvider).value != null;
    final count = signedIn ? ref.watch(cartProvider).value?.itemCount : null;
    return AdaptiveNavigation(
      items: customerTabs,
      selectedIndex: navIndexFor(customerTabs, location),
      badges: {_listTabIndex: ?count},
      child: child,
    );
  }
}
