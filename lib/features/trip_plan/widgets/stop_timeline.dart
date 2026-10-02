import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';

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

/// One Day Plan as a vertical timeline: numbered Stops joined by travel
/// segments, ending with the Night Stay. Numbers match the map markers.
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
            _TravelSegment(stop: stop, icon: localTransportIcon(transport)),
          _StopTile(
            number: i + 1,
            stop: stop,
            place: catalog.place(stop.placeId),
            selected: selectedIndex == i,
            onTap: onSelect == null ? null : () => onSelect!(i),
          ),
        ],
        if (stay != null)
          _NightStayTile(stay: stay, place: catalog.place(stay.placeId)),
      ],
    );
  }
}

/// Fixed-width time column + rail so every row lines up.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.leading,
    required this.rail,
    required this.child,
  });

  final Widget leading;
  final Widget rail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 52, child: leading),
          SizedBox(width: 40, child: rail),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.number,
    required this.stop,
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final Stop stop;
  final Place place;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return _TimelineRow(
      leading: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(stop.start.toJson(), style: theme.textTheme.labelLarge),
      ),
      rail: Column(
        children: [
          const SizedBox(height: 10),
          Semantics(
            label: 'จุดที่ $number',
            child: CircleAvatar(
              radius: 14,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: Text(
                '$number',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: VerticalDivider(
              width: 2,
              thickness: 2,
              color: colors.outlineVariant,
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          margin: EdgeInsets.zero,
          color: selected
              ? colors.secondaryContainer
              : colors.surfaceContainerLow,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _IconLabel(
                        icon: categoryIcon(place.category),
                        label: place.area ?? place.category.label,
                      ),
                      _IconLabel(
                        icon: Icons.schedule_outlined,
                        label: formatMinutes(stop.durationMin),
                      ),
                      _IconLabel(
                        icon: Icons.payments_outlined,
                        label: stop.cost == 0 ? 'ฟรี' : formatBaht(stop.cost),
                      ),
                    ],
                  ),
                  if (stop.note != null) ...[
                    const SizedBox(height: 8),
                    Text(stop.note!, style: muted),
                  ],
                  for (final warning in stop.warnings) ...[
                    const SizedBox(height: 8),
                    _IconLabel(
                      icon: Icons.warning_amber_outlined,
                      label: warning,
                      color: colors.error,
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

class _TravelSegment extends StatelessWidget {
  const _TravelSegment({required this.stop, required this.icon});

  final Stop stop;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _TimelineRow(
      leading: const SizedBox.shrink(),
      rail: Center(
        child: VerticalDivider(
          width: 2,
          thickness: 2,
          color: colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _IconLabel(
          icon: icon,
          label:
              '${formatMinutes(stop.travelFromPrevMin)} · ${stop.travelFromPrevKm.toStringAsFixed(1)} กม.',
        ),
      ),
    );
  }
}

class _NightStayTile extends StatelessWidget {
  const _NightStayTile({required this.stay, required this.place});

  final NightStay stay;
  final Place place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _TimelineRow(
      leading: const SizedBox.shrink(),
      rail: Column(
        children: [
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.tertiaryContainer,
            foregroundColor: colors.onTertiaryContainer,
            child: const Icon(Icons.bed_outlined, size: 16),
          ),
        ],
      ),
      child: Card.outlined(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text('พักคืนที่ ${stay.night} · ${place.name}'),
          subtitle: Text(
            '${stay.rooms} ห้อง · ${formatBaht(stay.cost)}'
            '${place.breakfastIncluded ? ' · รวมอาหารเช้า' : ''}',
          ),
        ),
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}
