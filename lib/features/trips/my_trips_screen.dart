import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../domain/domain.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/mascot_view.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/place_photo.dart';
import '../trip_plan/trip_plan_view_provider.dart';
import '../trip_request/trip_request_form_notifier.dart';
import 'trip_calendar_view.dart';
import 'trip_groups.dart';

/// ทริปของฉัน (#172): Draft Plans not saved yet, then Saved Trips ahead and
/// past, or the same trips on a monthly calendar.
class MyTripsScreen extends ConsumerStatefulWidget {
  const MyTripsScreen({super.key});

  @override
  ConsumerState<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends ConsumerState<MyTripsScreen> {
  var _calendar = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทริปของฉัน'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.view_agenda_outlined),
                  tooltip: 'รายการ',
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.calendar_month_outlined),
                  tooltip: 'ปฏิทิน',
                ),
              ],
              selected: {_calendar},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _calendar = s.single),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeThrough(
          switchKey: _calendar,
          child: _calendar ? const TripCalendarView() : const _TripList(),
        ),
      ),
    );
  }
}

class _TripList extends ConsumerWidget {
  const _TripList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedTripsProvider);
    final drafts = ref.watch(draftTripsProvider);
    final today = ref.watch(todayProvider);
    final margin = context.windowSizeClass.pageMargin;

    final trips = saved.value;
    if (trips == null) {
      return ListView(
        padding: EdgeInsets.all(margin),
        children: const [
          Skeleton(height: 220, radius: 20),
          SizedBox(height: 12),
          Skeleton(height: 84, radius: 20),
        ],
      );
    }
    if (trips.isEmpty && drafts.isEmpty) return const _Empty();

    final groups = TripGroups(trips, today);
    var index = 0;
    Widget entrance(Widget child) =>
        StaggeredEntrance(index: index++, child: child);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: WindowSizeClass.maxContentWidth,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(margin, 8, margin, 32),
          children: [
            if (drafts.isNotEmpty) ...[
              const _SectionTitle('ยังไม่บันทึก'),
              for (final MapEntry(key: id, value: draft)
                  in drafts.entries.toList().reversed)
                entrance(_DraftCard(id: id, draft: draft)),
            ],
            if (groups.ahead.isNotEmpty) ...[
              const _SectionTitle('กำลังจะถึง'),
              for (final trip in groups.ahead)
                entrance(
                  _Deletable(
                    trip: trip,
                    child: _UpcomingCard(trip: trip, today: today),
                  ),
                ),
            ],
            if (groups.past.isNotEmpty) ...[
              const _SectionTitle('ผ่านไปแล้ว'),
              for (final trip in groups.past)
                entrance(
                  _Deletable(
                    trip: trip,
                    child: _PastTile(trip: trip),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _provinceName(WidgetRef ref, String id) =>
    ref.watch(placeCatalogProvider).value?.findProvince(id)?.name ?? id;

/// A plan made this session that is not saved; opening it lets the user
/// save it.
class _DraftCard extends ConsumerWidget {
  const _DraftCard({required this.id, required this.draft});

  final String id;
  final DraftTrip draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final request = draft.request;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card.filled(
        color: colors.surfaceContainerLow,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          leading: CircleAvatar(
            backgroundColor: colors.secondaryContainer,
            child: Icon(Icons.auto_awesome, color: colors.onSecondaryContainer),
          ),
          title: Text(
            '${_provinceName(ref, draft.plan.destinationId)} '
            '${formatTripLength(request.startDate, request.endDate)}',
          ),
          subtitle: const Text('ยังไม่บันทึก หายไปเมื่อปิดแอป'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.tripPlan(id)),
        ),
      ),
    );
  }
}

/// A Saved Trip still ahead: the Destination's photo with a countdown.
class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard({required this.trip, required this.today});

  final Trip trip;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final request = trip.request;
    final province = _provinceName(ref, trip.plan.destinationId);
    final stops = trip.plan.days.fold(0, (n, d) => n + d.stops.length);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$province ${formatTripLength(request.startDate, request.endDate)}',
          style: theme.textTheme.titleMedium,
        ),
        Text(
          '${formatDateRange(request.startDate, request.endDate)}'
          ' · ${request.travellerCount} คน · $stops จุดแวะ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
    final cost = _Cost(cost: trip.plan.cost);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: trip.id == null
            ? null
            : () => context.push(AppRoutes.tripPlan(trip.id!)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlacePhoto(
                    id: trip.plan.destinationId,
                    label: province,
                    heroTag: 'trip-${trip.id}',
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _Chip(
                      label: countdownLabel(trip, today),
                      background: colors.tertiaryContainer,
                      foreground: colors.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              // Large text puts the cost under the details.
              child: MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        details,
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerRight, child: cost),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: details),
                        const SizedBox(width: 8),
                        cost,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Saved Trip already over, kept short.
class _PastTile extends ConsumerWidget {
  const _PastTile({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = trip.request;
    final province = _provinceName(ref, trip.plan.destinationId);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(
            dimension: 56,
            child: PlacePhoto(id: trip.plan.destinationId, label: province),
          ),
        ),
        title: Text(
          '$province ${formatTripLength(request.startDate, request.endDate)}',
        ),
        subtitle: Text(
          '${formatDateRange(request.startDate, request.endDate)}'
          ' · ${request.travellerCount} คน',
        ),
        trailing: _Cost(cost: trip.plan.cost),
        onTap: trip.id == null
            ? null
            : () => context.push(AppRoutes.tripPlan(trip.id!)),
      ),
    );
  }
}

class _Cost extends StatelessWidget {
  const _Cost({required this.cost});

  final CostEstimate cost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatBaht(cost.total),
          style: theme.textTheme.titleMedium?.copyWith(
            color: cost.isOverBudget ? colors.error : colors.primary,
          ),
        ),
        if (cost.isOverBudget)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_outlined, size: 14, color: colors.error),
              const SizedBox(width: 2),
              Text(
                'เกินงบ',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.error,
                ),
              ),
            ],
          )
        else
          Text(
            'ราคาโดยประมาณ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Swipe left to delete, with undo.
class _Deletable extends ConsumerWidget {
  const _Deletable({required this.trip, required this.child});

  final Trip trip;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final repo = ref.read(tripRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final province = _provinceName(ref, trip.plan.destinationId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(trip.id ?? trip.createdAt.toIso8601String()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
        ),
        onDismissed: (_) {
          if (trip.id != null) repo.deleteTrip(trip.id!);
          messenger
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('ลบทริป$provinceแล้ว'),
                action: SnackBarAction(
                  label: 'เลิกทำ',
                  onPressed: () => repo.saveTrip(trip),
                ),
              ),
            );
        },
        child: child,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotView(pose: MascotPose.map, size: 140),
            const SizedBox(height: 16),
            Text('ยังไม่มีทริป', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'แผนที่คุณบันทึกจะแสดงที่นี่ พร้อมนับถอยหลังวันเดินทาง',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.newTrip),
              icon: const Icon(Icons.add),
              label: const Text('เริ่มวางแผนทริปแรก'),
            ),
          ],
        ),
      ),
    );
  }
}
