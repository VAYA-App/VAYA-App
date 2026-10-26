import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/motion.dart';
import '../router.dart';
import 'window_size_class.dart';

/// A shell tab backed by a [StatefulShellBranch].
typedef _Tab = ({IconData icon, IconData selectedIcon, String label});

/// Top-level navigation that follows M3 window size classes.
///
/// Compact windows get a bottom [NavigationBar] with five items, the middle
/// one being the "สร้างทริป" action that opens the trip request form.
/// Wider windows get a [NavigationRail] with the action as its FAB.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// In branch order (see `router.dart`).
  static const List<_Tab> _tabs = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'หน้าแรก'),
    (icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: 'สำรวจ'),
    (
      icon: Icons.luggage_outlined,
      selectedIcon: Icons.luggage,
      label: 'ทริปของฉัน',
    ),
    (icon: Icons.person_outline, selectedIcon: Icons.person, label: 'โปรไฟล์'),
  ];

  /// Position of the create action in the bottom bar.
  static const _createIndex = 2;

  void _goTo(int branch) => navigationShell.goBranch(
    branch,
    initialLocation: branch == navigationShell.currentIndex,
  );

  void _create(BuildContext context) => context.push(AppRoutes.newTrip);

  @override
  Widget build(BuildContext context) {
    final sizeClass = context.windowSizeClass;
    final branch = navigationShell.currentIndex;
    final body = FadeThrough(switchKey: branch, child: navigationShell);

    if (sizeClass == WindowSizeClass.compact) {
      NavigationDestination tab(_Tab t) => NavigationDestination(
        icon: Icon(t.icon),
        selectedIcon: Icon(t.selectedIcon),
        label: t.label,
      );
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: branch < _createIndex ? branch : branch + 1,
          onDestinationSelected: (index) {
            if (index == _createIndex) return _create(context);
            _goTo(index < _createIndex ? index : index - 1);
          },
          destinations: [
            tab(_tabs[0]),
            tab(_tabs[1]),
            const NavigationDestination(
              icon: _CreateIcon(),
              label: 'สร้างทริป',
              tooltip: 'วางแผนทริปใหม่',
            ),
            tab(_tabs[2]),
            tab(_tabs[3]),
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
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: extended
                    ? FloatingActionButton.extended(
                        onPressed: () => _create(context),
                        icon: const Icon(Icons.add),
                        label: const Text('สร้างทริป'),
                      )
                    : FloatingActionButton(
                        onPressed: () => _create(context),
                        tooltip: 'สร้างทริป',
                        child: const Icon(Icons.add),
                      ),
              ),
              selectedIndex: branch,
              onDestinationSelected: _goTo,
              destinations: [
                for (final t in _tabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: Text(t.label),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// The raised circular "+" in the middle of the bottom bar.
class _CreateIcon extends StatelessWidget {
  const _CreateIcon();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(Icons.add, color: colors.onPrimary),
      ),
    );
  }
}
