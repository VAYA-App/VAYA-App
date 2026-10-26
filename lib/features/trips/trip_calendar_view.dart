import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../domain/domain.dart';
import '../../shared/formatters.dart';
import '../trip_request/trip_request_form_notifier.dart';

const _weekdays = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
const _months = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

/// Every saved trip on a monthly calendar (#50), the calendar view of
/// ทริปของฉัน (#172). Opens on the month of the next trip, or this month
/// when none is ahead.
class TripCalendarView extends ConsumerStatefulWidget {
  const TripCalendarView({super.key});

  @override
  ConsumerState<TripCalendarView> createState() => _TripCalendarViewState();
}

class _TripCalendarViewState extends ConsumerState<TripCalendarView> {
  /// First day of the month shown; set once the trips are known.
  DateTime? _month;

  DateTime _initialMonth(List<Trip> trips, DateTime today) {
    final ahead = [
      for (final t in trips)
        if (!t.request.endDate.isBefore(today)) t.request.startDate,
    ]..sort();
    final date = ahead.isEmpty ? today : ahead.first;
    return DateTime(date.year, date.month);
  }

  void _move(int months) =>
      setState(() => _month = DateTime(_month!.year, _month!.month + months));

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(savedTripsProvider).value;
    final catalog = ref.watch(placeCatalogProvider).value;
    final today = ref.watch(todayProvider);

    return trips == null
        ? const Center(child: CircularProgressIndicator())
        : Builder(
            builder: (context) {
              final month = _month ??= _initialMonth(trips, today);
              String name(Trip t) =>
                  catalog?.findProvince(t.plan.destinationId)?.name ??
                  t.plan.destinationId;
              final inMonth =
                  [
                    for (final t in trips)
                      if (_overlaps(t, month)) t,
                  ]..sort(
                    (a, b) =>
                        a.request.startDate.compareTo(b.request.startDate),
                  );
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: EdgeInsets.all(context.windowSizeClass.pageMargin),
                    children: [
                      _MonthHeader(
                        month: month,
                        onPrevious: () => _move(-1),
                        onNext: () => _move(1),
                      ),
                      const SizedBox(height: 8),
                      _MonthGrid(
                        month: month,
                        today: today,
                        trips: trips,
                        nameOf: name,
                      ),
                      const SizedBox(height: 24),
                      if (inMonth.isEmpty)
                        Text(
                          'ไม่มีทริปในเดือนนี้',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        )
                      else
                        for (final trip in inMonth)
                          Card.outlined(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: const Icon(Icons.luggage_outlined),
                              title: Text(name(trip)),
                              subtitle: Text(
                                '${formatDateRange(trip.request.startDate, trip.request.endDate)}'
                                ' · ${trip.request.travellerCount} คน',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: trip.id == null
                                  ? null
                                  : () => context.push(
                                      AppRoutes.tripPlan(trip.id!),
                                    ),
                            ),
                          ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  static bool _overlaps(Trip trip, DateTime month) {
    final next = DateTime(month.year, month.month + 1);
    return trip.request.startDate.isBefore(next) &&
        !trip.request.endDate.isBefore(month);
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          tooltip: 'เดือนก่อน',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            // Buddhist year, as Thai calendars show it.
            '${_months[month.month - 1]} ${month.year + 543}',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          onPressed: onNext,
          tooltip: 'เดือนถัดไป',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// Weeks start on Monday. Trip days are filled and open their trip.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.trips,
    required this.nameOf,
  });

  final DateTime month;
  final DateTime today;
  final List<Trip> trips;
  final String Function(Trip) nameOf;

  Trip? _tripOn(DateTime day) {
    for (final t in trips) {
      if (!day.isBefore(t.request.startDate) &&
          !day.isAfter(t.request.endDate)) {
        return t;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = month.weekday - 1;
    final cells = (leading + daysInMonth + 6) ~/ 7 * 7;

    Widget dayCell(int index) {
      final dayNumber = index - leading + 1;
      if (dayNumber < 1 || dayNumber > daysInMonth) {
        return const SizedBox.shrink();
      }
      final day = DateTime(month.year, month.month, dayNumber);
      final trip = _tripOn(day);
      final isToday = day == today;
      final label = Text(
        '$dayNumber',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: trip != null ? colors.onPrimaryContainer : colors.onSurface,
          fontWeight: trip != null || isToday ? FontWeight.bold : null,
        ),
      );
      return Semantics(
        label: [
          'วันที่ $dayNumber',
          if (isToday) 'วันนี้',
          if (trip != null) 'ทริป${nameOf(trip)}',
        ].join(' '),
        button: trip != null,
        container: true,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: trip != null ? colors.primaryContainer : colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isToday
                  ? BorderSide(color: colors.primary, width: 2)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: trip?.id == null
                  ? null
                  : () => context.push(AppRoutes.tripPlan(trip!.id!)),
              child: Center(child: FittedBox(child: label)),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (final d in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var week = 0; week < cells ~/ 7; week++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: dayCell(week * 7 + d),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
