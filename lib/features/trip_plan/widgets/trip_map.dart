import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';

/// Map of one Day Plan with numbered markers matching the timeline.
/// Placeholder until the OpenStreetMap implementation lands in #40.
class TripMap extends StatelessWidget {
  const TripMap({
    super.key,
    required this.day,
    required this.catalog,
    this.nightStay,
    this.selectedIndex,
    this.onSelect,
  });

  final DayPlan day;
  final PlaceCatalog catalog;
  final NightStay? nightStay;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text('แผนที่ (#40)', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
