import 'package:flutter/material.dart';

import '../../core/widgets/space_scaffold.dart';

const courierTabs = [
  SpaceTab(
    'Mes courses',
    Icons.delivery_dining_outlined,
    '/courier/deliveries',
    selectedIcon: Icons.delivery_dining,
  ),
  SpaceTab(
    'Disponibles',
    Icons.map_outlined,
    '/courier/available',
    selectedIcon: Icons.map,
  ),
  SpaceTab(
    'Profil',
    Icons.badge_outlined,
    '/courier/profile',
    selectedIcon: Icons.badge,
  ),
];

/// Courier space: the deliveries they carry, the open ones of their zones
/// and their profile.
class CourierShell extends StatelessWidget {
  const CourierShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) => SpaceScaffold(
    space: AppSpace.courier,
    tabs: courierTabs,
    location: location,
    child: child,
  );
}
