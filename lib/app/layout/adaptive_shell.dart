import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'window_size_class.dart';

typedef _Destination = ({IconData icon, IconData selectedIcon, String label});

/// Top-level navigation that follows M3 window size classes:
/// a bottom [NavigationBar] on compact windows and a [NavigationRail]
/// (extended from large windows up) everywhere else.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_Destination> _destinations = [
    (
      icon: Icons.luggage_outlined,
      selectedIcon: Icons.luggage,
      label: 'ทริปของฉัน',
    ),
    (icon: Icons.person_outline, selectedIcon: Icons.person, label: 'โปรไฟล์'),
  ];

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final sizeClass = context.windowSizeClass;

    if (sizeClass == WindowSizeClass.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = sizeClass.isAtLeast(WindowSizeClass.large);
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
