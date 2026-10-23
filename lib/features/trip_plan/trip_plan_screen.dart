import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../domain/domain.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/coming_soon.dart';
import 'trip_plan_view_provider.dart';
import 'widgets/budget_advice_list.dart';
import 'widgets/cost_summary_card.dart';
import 'widgets/day_weather.dart';
import 'widgets/over_budget_banner.dart';
import 'widgets/stop_detail_sheet.dart';
import 'widgets/stop_timeline.dart';
import 'widgets/trip_map.dart';

/// A Trip Plan shown day by day (#39, restyled in #66).
class TripPlanScreen extends ConsumerWidget {
  const TripPlanScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(tripPlanViewProvider(tripId))) {
      AsyncData(value: final view?) => _TripPlanBody(
        tripId: tripId,
        view: view,
      ),
      AsyncData() => const _MessageScaffold(
        icon: Icons.search_off,
        message: 'ไม่พบแผนการเดินทางนี้',
      ),
      AsyncError() => const _MessageScaffold(
        icon: Icons.error_outline,
        message: 'เปิดแผนการเดินทางไม่สำเร็จ',
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _TripPlanBody extends StatefulWidget {
  const _TripPlanBody({required this.tripId, required this.view});

  final String tripId;

  final TripPlanView view;

  @override
  State<_TripPlanBody> createState() => _TripPlanBodyState();
}

class _TripPlanBodyState extends State<_TripPlanBody> {
  var _day = 0;

  /// Compact windows show either the timeline or the map.
  var _showMap = false;

  /// Highlighted Stop of the selected day, shared by timeline and map.
  int? _selectedStop;

  TripPlan get _plan => widget.view.plan;
  DayPlan get _dayPlan => _plan.days[_day];

  /// The Night Stay that ends the selected day (none on the last day).
  NightStay? get _nightStay {
    for (final stay in _plan.nightStays) {
      if (stay.night == _day + 1) return stay;
    }
    return null;
  }

  void _selectDay(int day) => setState(() {
    _day = day;
    _selectedStop = null;
  });

  void _selectStop(int index) {
    setState(() => _selectedStop = index);
    final stop = _dayPlan.stops[index];
    showStopDetailSheet(
      context,
      number: index + 1,
      stop: stop,
      place: widget.view.catalog.place(stop.placeId),
      date: _dayPlan.date,
    );
  }

  Widget _timeline() => StopTimeline(
    day: _dayPlan,
    catalog: widget.view.catalog,
    transport: widget.view.request.localTransportMode,
    nightStay: _nightStay,
    selectedIndex: _selectedStop,
    onSelect: _selectStop,
  );

  Widget _map() => TripMap(
    day: _dayPlan,
    catalog: widget.view.catalog,
    nightStay: _nightStay,
    selectedIndex: _selectedStop,
    onSelect: _selectStop,
  );

  Widget _dayChips() =>
      _DayChips(days: _plan.days, selected: _day, onSelected: _selectDay);

  @override
  Widget build(BuildContext context) {
    final sizeClass = context.windowSizeClass;
    final margin = sizeClass.pageMargin;
    final over = _plan.cost.isOverBudget;
    final summary = [
      if (over) ...[
        OverBudgetBanner(
          cost: _plan.cost,
          hasAdvice: _plan.overBudgetAdvice.isNotEmpty,
          canShorten: _plan.days.length > 1,
        ),
        const SizedBox(height: 12),
      ],
      _TripSummaryCard(view: widget.view),
      if (over) _OverBudgetHelp(tripId: widget.tripId, plan: _plan),
    ];
    final dayHeader = _DayHeader(
      dayIndex: _day,
      date: _dayPlan.date,
      pace: widget.view.request.pace,
    );
    final weather = DayWeatherRow(
      place: widget.view.destination.center,
      start: widget.view.request.startDate,
      end: widget.view.request.endDate,
      date: _dayPlan.date,
    );

    final Widget body;
    if (sizeClass.isAtLeast(WindowSizeClass.expanded)) {
      body = Row(
        children: [
          Expanded(
            flex: 5,
            child: ListView(
              padding: EdgeInsets.all(margin),
              children: [
                ...summary,
                const SizedBox(height: 20),
                _dayChips(),
                const SizedBox(height: 20),
                dayHeader,
                const SizedBox(height: 8),
                weather,
                const SizedBox(height: 16),
                _timeline(),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, margin, margin, margin),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _map(),
              ),
            ),
          ),
        ],
      );
    } else {
      final toggle = SizedBox(
        width: double.infinity,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.view_timeline_outlined),
              label: Text('ไทม์ไลน์'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.map_outlined),
              label: Text('แผนที่'),
            ),
          ],
          selected: {_showMap},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _showMap = s.single),
        ),
      );
      body = _showMap
          ? Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(margin, 8, margin, 12),
                  child: Column(
                    children: [toggle, const SizedBox(height: 12), _dayChips()],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margin, 0, margin, margin),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _map(),
                    ),
                  ),
                ),
              ],
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(margin, 8, margin, margin),
              children: [
                ...summary,
                const SizedBox(height: 20),
                toggle,
                const SizedBox(height: 12),
                _dayChips(),
                const SizedBox(height: 16),
                _MapPreview(
                  day: _dayPlan,
                  dayIndex: _day,
                  map: TripMap(
                    day: _dayPlan,
                    catalog: widget.view.catalog,
                    nightStay: _nightStay,
                    interactive: false,
                  ),
                  onOpen: () => setState(() => _showMap = true),
                ),
                const SizedBox(height: 24),
                dayHeader,
                const SizedBox(height: 8),
                weather,
                const SizedBox(height: 16),
                _timeline(),
              ],
            );
    }

    return Scaffold(
      appBar: AppBar(
        // Opened directly (e.g. from a link): offer a way home.
        leading: !(ModalRoute.of(context)?.isFirst ?? false)
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'กลับหน้าแรก',
                onPressed: () => context.go(AppRoutes.home),
              ),
        title: const Text('แผนการเดินทาง'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'แชร์แผน',
            onPressed: () => showComingSoon(context, 'แชร์แผน', issue: 48),
          ),
          if (widget.view.savedTrip case final trip?) _TripMenu(trip: trip),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: _BottomActions(view: widget.view),
    );
  }
}

/// A small, non-interactive map of the selected day; tap to open the map.
class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.day,
    required this.dayIndex,
    required this.map,
    required this.onOpen,
  });

  final DayPlan day;
  final int dayIndex;
  final Widget map;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final km = day.stops.fold<double>(0, (sum, s) => sum + s.travelFromPrevKm);

    return Semantics(
      button: true,
      label: 'เปิดแผนที่วันที่ ${dayIndex + 1}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(child: map),
              Positioned(
                left: 12,
                bottom: 12,
                right: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLowest.withValues(
                        alpha: 0.92,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route, size: 16, color: colors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'วันที่ ${dayIndex + 1}: ${day.stops.length} จุด '
                              '· รวม ~${km.round()} กม.',
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onOpen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// More actions on a saved trip: delete it after confirming (#43).
class _TripMenu extends ConsumerWidget {
  const _TripMenu({required this.trip});

  final Trip trip;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('ลบทริปนี้?'),
        content: const Text('ทริปที่ลบแล้วจะหายจากรายการทริปของคุณ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(tripRepositoryProvider).deleteTrip(trip.id!);
      messenger.showSnackBar(const SnackBar(content: Text('ลบทริปแล้ว')));
      if (context.mounted) context.go(AppRoutes.home);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ลบทริปไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context, ref),
          child: const Text('ลบทริป'),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        icon: const Icon(Icons.more_vert),
        tooltip: 'ตัวเลือกเพิ่มเติม',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Saving the plan (#43) and AI edits, which come next (#46).
class _BottomActions extends ConsumerStatefulWidget {
  const _BottomActions({required this.view});

  final TripPlanView view;

  @override
  ConsumerState<_BottomActions> createState() => _BottomActionsState();
}

class _BottomActionsState extends ConsumerState<_BottomActions> {
  var _saving = false;

  Future<void> _save() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    setState(() => _saving = true);
    try {
      final trip = await ref
          .read(tripRepositoryProvider)
          .saveTrip(
            Trip(
              ownerUid: user.uid,
              createdAt: now,
              updatedAt: now,
              request: widget.view.request,
              plan: widget.view.plan,
            ),
          );
      messenger.showSnackBar(const SnackBar(content: Text('บันทึกแล้ว')));
      // Reopen as the saved trip, so saving twice is not possible and the
      // delete menu appears.
      if (mounted) context.replace(AppRoutes.tripPlan(trip.id!));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final saved = widget.view.isSaved;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saved || _saving ? null : _save,
                      icon: Icon(
                        saved ? Icons.bookmark_added : Icons.bookmark_border,
                      ),
                      label: Text(saved ? 'บันทึกแล้ว' : 'บันทึกทริป'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.tertiary,
                        foregroundColor: colors.onTertiary,
                      ),
                      onPressed: () =>
                          showComingSoon(context, 'ให้ AI ปรับแผน', issue: 46),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('ให้ AI ปรับแผน'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ways to save on an Over Budget plan and, when they are not enough, the
/// budget the trip needs (#38).
class _OverBudgetHelp extends ConsumerWidget {
  const _OverBudgetHelp({required this.tripId, required this.plan});

  final String tripId;
  final TripPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rescue = ref.watch(budgetRescueProvider(tripId)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.overBudgetAdvice.isNotEmpty) ...[
          const SizedBox(height: 16),
          BudgetAdviceList(advice: plan.overBudgetAdvice),
        ],
        if (rescue != null) ...[
          const SizedBox(height: 12),
          BudgetRescueCard(
            rescue: rescue,
            advice: plan.overBudgetAdvice,
            dayCount: plan.days.length,
            budget: plan.cost.budget,
          ),
        ],
      ],
    );
  }
}

/// Trip name, budget status, the cost summary (#36) and accommodation
/// (Stitch summary).
class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.view});

  final TripPlanView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final plan = view.plan;
    final request = view.request;
    final cost = plan.cost;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final stay = plan.nightStays.isEmpty ? null : plan.nightStays.first;
    final days = plan.days.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.preferenceTags.map((t) => t.label).join(' & '),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${view.destination.name} '
                        '${days == 1 ? '1 วัน' : '$days วัน ${days - 1} คืน'}',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                // Over Budget is the banner's to say, once.
                if (!cost.isOverBudget) ...[
                  const SizedBox(width: 8),
                  const _WithinBudgetBadge(),
                ],
              ],
            ),
            const SizedBox(height: 16),
            CostSummaryCard(cost: cost, travellerCount: request.travellerCount),
            if (stay != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.bed_outlined,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ที่พัก ${view.catalog.place(stay.placeId).name} '
                      '(${formatBaht(stay.cost)} × ${plan.nightStays.length} คืน)',
                      style: muted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WithinBudgetBadge extends StatelessWidget {
  const _WithinBudgetBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fg = colors.onSecondaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: fg),
            const SizedBox(width: 4),
            Text(
              'อยู่ในงบ',
              style: theme.textTheme.labelMedium?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChips extends StatelessWidget {
  const _DayChips({
    required this.days,
    required this.selected,
    required this.onSelected,
  });

  final List<DayPlan> days;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, day) in days.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            ChoiceChip(
              label: Text('วันที่ ${i + 1} · ${formatThaiShortDate(day.date)}'),
              selected: i == selected,
              showCheckmark: false,
              selectedColor: colors.primary,
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color: i == selected ? colors.onPrimary : colors.onSurface,
              ),
              onSelected: (_) => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.dayIndex,
    required this.date,
    required this.pace,
  });

  final int dayIndex;
  final DateTime date;
  final Pace pace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'กิจกรรมวันที่ ${dayIndex + 1} (${formatThaiShortDate(date)})',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Text(
          'จังหวะ: ${pace.label}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message, style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('กลับหน้าแรก'),
            ),
          ],
        ),
      ),
    );
  }
}
