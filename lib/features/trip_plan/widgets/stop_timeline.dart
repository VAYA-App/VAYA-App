import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/motion.dart';

/// `90` → `1 ชม. 30 นาที`.
String formatMinutes(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m นาที';
  if (m == 0) return '$h ชม.';
  return '$h ชม. $m นาที';
}

IconData categoryIcon(PlaceCategory category) => switch (category) {
  PlaceCategory.attraction => Icons.photo_camera_outlined,
  PlaceCategory.restaurant => Icons.restaurant_outlined,
  PlaceCategory.accommodation => Icons.hotel_outlined,
};

IconData localTransportIcon(LocalTransportMode mode) => switch (mode) {
  LocalTransportMode.rentalCar => Icons.car_rental_outlined,
  LocalTransportMode.rentalMotorbike => Icons.two_wheeler_outlined,
  LocalTransportMode.taxi => Icons.local_taxi_outlined,
  LocalTransportMode.publicTransport => Icons.directions_transit_outlined,
};

/// Small pill naming a Place's category, coloured per category.
class CategoryPill extends StatelessWidget {
  const CategoryPill({super.key, required this.category});

  final PlaceCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (bg, fg) = switch (category) {
      PlaceCategory.attraction => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      PlaceCategory.restaurant => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      PlaceCategory.accommodation => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          category.label,
          style: theme.textTheme.labelSmall?.copyWith(color: fg),
        ),
      ),
    );
  }
}

/// One Day Plan as a minimal vertical timeline: numbered Stops on a thin
/// emerald rail, travel rows between them, and the Night Stay at the end.
/// Numbers match the map markers. Stops appear one after another when the
/// timeline is first shown (#85).
class StopTimeline extends StatelessWidget {
  const StopTimeline({
    super.key,
    required this.day,
    required this.catalog,
    required this.transport,
    this.nightStay,
    this.selectedIndex,
    this.onSelect,
  });

  final DayPlan day;
  final PlaceCatalog catalog;
  final LocalTransportMode transport;
  final NightStay? nightStay;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final stay = nightStay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, stop) in day.stops.indexed) ...[
          if (stop.travelFromPrevMin > 0)
            StaggeredEntrance(
              index: i,
              child: _TravelRow(
                stop: stop,
                icon: localTransportIcon(transport),
              ),
            ),
          StaggeredEntrance(
            index: i,
            child: _StopEntry(
              number: i + 1,
              stop: stop,
              place: catalog.place(stop.placeId),
              selected: selectedIndex == i,
              isLast: i == day.stops.length - 1 && stay == null,
              onTap: onSelect == null ? null : () => onSelect!(i),
            ),
          ),
        ],
        if (stay != null)
          StaggeredEntrance(
            index: day.stops.length,
            child: _NightStayEntry(
              stay: stay,
              place: catalog.place(stay.placeId),
            ),
          ),
      ],
    );
  }
}

/// Rail column + content, so every row lines up on the same rail.
class _Row extends StatelessWidget {
  const _Row({required this.rail, required this.child});

  final Widget rail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 40, child: rail),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) => Center(
    child: VerticalDivider(
      width: 2,
      thickness: 2,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
    ),
  );
}

class _StopEntry extends StatelessWidget {
  const _StopEntry({
    required this.number,
    required this.stop,
    required this.place,
    required this.selected,
    required this.isLast,
    required this.onTap,
  });

  final int number;
  final Stop stop;
  final Place place;
  final bool selected;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final costLabel = stop.cost == 0
        ? 'ไม่มีค่าใช้จ่าย'
        : '${formatBaht(stop.cost)} · '
              '${place.category == PlaceCategory.restaurant ? 'ค่าอาหาร' : 'ค่าเข้าชม'}';

    return _Row(
      rail: Column(
        children: [
          const SizedBox(height: 16),
          Semantics(
            label: 'จุดที่ $number',
            child: CircleAvatar(
              radius: 14,
              backgroundColor: colors.primary,
              child: Text(
                '$number',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onPrimary,
                ),
              ),
            ),
          ),
          if (!isLast) const Expanded(child: _Line()),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected
                  ? colors.primary
                  : colors.outlineVariant.withValues(alpha: 0.6),
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${stop.start.toJson()} – ${stop.end.toJson()} '
                          '(${formatMinutes(stop.durationMin)})',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
                      CategoryPill(category: place.category),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(place.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    [?place.area, place.shortDescription].join(' · '),
                    style: muted,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    costLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  if (stop.note != null) ...[
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: colors.tertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(stop.note!, style: muted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  for (final warning in stop.warnings) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          size: 16,
                          color: colors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warning,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TravelRow extends StatelessWidget {
  const _TravelRow({required this.stop, required this.icon});

  final Stop stop;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _Row(
      rail: const _Line(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'เดินทาง ${stop.travelFromPrevKm.toStringAsFixed(1)} กม. '
                '(ประมาณ ${formatMinutes(stop.travelFromPrevMin)})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NightStayEntry extends StatelessWidget {
  const _NightStayEntry({required this.stay, required this.place});

  final NightStay stay;
  final Place place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _Row(
      rail: Column(
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.tertiaryContainer,
            child: Icon(
              Icons.bed_outlined,
              size: 16,
              color: colors.onTertiaryContainer,
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Card(
          child: ListTile(
            title: Text('พักคืนที่ ${stay.night} · ${place.name}'),
            subtitle: Text(
              '${stay.rooms} ห้อง · ${formatBaht(stay.cost)}'
              '${place.breakfastIncluded ? ' · รวมอาหารเช้า' : ''}',
            ),
          ),
        ),
      ),
    );
  }
}
