import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/identity/data/auth_providers.dart';
import '../../features/identity/models/auth_user.dart';
import 'app_navigation_bar.dart';
import 'async_views.dart';

/// The spaces of the app, one per role: each has its own screens and
/// navigation, and only the users holding the role can enter it.
enum AppSpace {
  customer('Espace client', Icons.shopping_basket_outlined, '/'),
  merchant('Espace marchand', Icons.storefront_outlined, '/merchant/orders'),
  courier('Espace coursier', Icons.delivery_dining, '/courier/deliveries'),
  moderation('Modération', Icons.fact_check_outlined, '/moderation/pending');

  const AppSpace(this.label, this.icon, this.home);

  final String label;
  final IconData icon;

  /// First screen of the space.
  final String home;

  /// Role required to enter (none for the customer space).
  String? get role => switch (this) {
    AppSpace.customer => null,
    AppSpace.merchant => 'merchant',
    AppSpace.courier => 'courier',
    AppSpace.moderation => 'moderator',
  };

  bool isOpenTo(AuthUser user) => switch (this) {
    AppSpace.customer => true,
    // Admins moderate as well (same rule as the API).
    AppSpace.moderation => user.hasRole('moderator') || user.hasRole('admin'),
    _ => user.hasRole(role!),
  };
}

/// The spaces [user] can enter, the customer space first.
List<AppSpace> spacesOf(AuthUser user) => [
  for (final space in AppSpace.values)
    if (space.isOpenTo(user)) space,
];

/// One destination of a space's navigation.
typedef SpaceTab = NavItem;

/// Index of the tab showing [location] (the longest matching path wins).
int spaceTabIndex(List<SpaceTab> tabs, String location) =>
    navIndexFor(tabs, location);

/// Frame of a role space: title, space switcher, the role gate and the
/// space's own navigation (bar or rail) around the current tab ([child]).
class SpaceScaffold extends StatelessWidget {
  const SpaceScaffold({
    super.key,
    required this.space,
    required this.tabs,
    required this.location,
    required this.child,
    this.showTabs = true,
  });

  final AppSpace space;
  final List<SpaceTab> tabs;
  final String location;
  final Widget child;

  /// False while the space is not set up yet (a merchant without shop).
  final bool showTabs;

  @override
  Widget build(BuildContext context) {
    final index = spaceTabIndex(tabs, location);
    return AdaptiveNavigation(
      items: tabs,
      selectedIndex: index,
      showNavigation: showTabs,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(space.label, style: Theme.of(context).textTheme.labelSmall),
            Text(showTabs ? tabs[index].label : space.label),
          ],
        ),
        actions: [SpaceSwitcher(current: space)],
      ),
      // isOpenTo, not SignedInGate.role: admins enter the moderation space.
      child: SignedInGate(
        signInMessage:
            'Connectez-vous pour accéder à votre ${space.label.toLowerCase()}.',
        builder: (user) => space.isOpenTo(user)
            ? child
            : const EmptyState(
                icon: Icons.block,
                title: 'Cet espace est réservé à un autre profil.',
              ),
      ),
    );
  }
}

/// Switches between the spaces of the signed-in user; hidden when the user
/// has only the customer space.
class SpaceSwitcher extends ConsumerWidget {
  const SpaceSwitcher({super.key, required this.current});

  final AppSpace current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).value;
    final others = user == null
        ? const <AppSpace>[]
        : spacesOf(user).where((space) => space != current).toList();
    if (others.isEmpty) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<AppSpace>(
      tooltip: 'Changer d’espace',
      icon: const Icon(Icons.swap_horiz),
      onSelected: (space) => context.go(space.home),
      itemBuilder: (context) => [
        for (final space in others)
          PopupMenuItem(
            value: space,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(space.icon),
              title: Text(space.label),
            ),
          ),
      ],
    );
  }
}
