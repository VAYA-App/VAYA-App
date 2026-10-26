import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../domain/domain.dart';
import '../../planner/plan_editor.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/place_photo.dart';
import '../assistant/plan_chat_panel.dart';
import 'trip_plan_view_provider.dart';
import 'trip_calendar_export.dart';
import 'trip_summary.dart';
import 'widgets/budget_advice_list.dart';
import 'widgets/cost_breakdown_sheet.dart';
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

class _TripPlanBody extends ConsumerStatefulWidget {
  const _TripPlanBody({required this.tripId, required this.view});

  final String tripId;

  final TripPlanView view;

  @override
  ConsumerState<_TripPlanBody> createState() => _TripPlanBodyState();
}

class _TripPlanBodyState extends ConsumerState<_TripPlanBody> {
  var _day = 0;

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

  Future<void> _selectStop(int index) async {
    setState(() => _selectedStop = index);
    final stop = _dayPlan.stops[index];
    final place = widget.view.catalog.place(stop.placeId);
    final action = await showStopDetailSheet(
      context,
      number: index + 1,
      stop: stop,
      place: place,
      date: _dayPlan.date,
      alternatives: PlanEditor.alternatives(
        _plan,
        widget.view.catalog,
        day: _day,
        index: index,
        excluded: ref.read(tasteProfileProvider).disliked,
      ),
      canRemove: _dayPlan.stops.length > 1,
    );
    if (action == null || !mounted) return;
    await _edit(
      switch (action) {
        SwapStop(:final place) => ReplaceStop(
          day: _day,
          index: index,
          placeId: place.id,
        ),
        DeleteStop() => RemoveStop(day: _day, index: index),
      },
      done: switch (action) {
        SwapStop(place: final next) =>
          'เปลี่ยน${place.name}เป็น${next.name}แล้ว',
        DeleteStop() => 'ลบ${place.name}ออกจากแผนแล้ว',
      },
    );
  }

  /// The AI chat for this plan in a sheet (#46). When a read-only plan
  /// becomes a draft, the screen follows it.
  void _openChat() {
    final router = GoRouter.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Lift the sheet above the keyboard and keep the input clear of the
      // system navigation bar, or the typed text hides behind them (#180).
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Text(
                  'ให้ AI ปรับแผน',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Expanded(
                  child: PlanChatPanel(
                    tripId: widget.tripId,
                    onTripChanged: (id) =>
                        router.replace(AppRoutes.tripPlan(id)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Applies [edit], reopens the plan under its new id when a mock became a
  /// draft, and offers to undo (#45).
  Future<void> _edit(PlanEdit edit, {required String done}) async {
    final edits = ref.read(tripPlanEditsProvider);
    final before = widget.view;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final id = await edits.apply(widget.tripId, edit);
      if (mounted) setState(() => _selectedStop = null);
      if (id != widget.tripId) router.replace(AppRoutes.tripPlan(id));
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(done),
            action: SnackBarAction(
              label: 'เลิกทำ',
              onPressed: () => edits.restore(id, before.plan),
            ),
          ),
        );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('แก้แผนไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  /// Every Stop as a calendar event, through the share sheet (#47).
  Future<void> _exportCalendar(BuildContext context, WidgetRef ref) => ref.read(
    shareCalendarProvider,
  )(tripCalendarIcs(widget.view), origin: _originOf(context));

  /// Shares the plan as text; [context] is the button's, for the iPad
  /// popover (#48).
  Future<void> _share(BuildContext context, WidgetRef ref) => ref.read(
    shareTextProvider,
  )(tripSummaryText(widget.view), origin: _originOf(context));

  Widget _timeline() => StopTimeline(
    day: _dayPlan,
    catalog: widget.view.catalog,
    transport: widget.view.request.localTransportMode,
    nightStay: _nightStay,
    selectedIndex: _selectedStop,
    onSelect: _selectStop,
  );

  /// Tapping a pin picks its Stop and glides there; the timeline opens
  /// the Stop's details.
  Widget _map({EdgeInsets padding = EdgeInsets.zero}) => TripMap(
    day: _dayPlan,
    catalog: widget.view.catalog,
    nightStay: _nightStay,
    selectedIndex: _selectedStop,
    onSelect: (i) => setState(() => _selectedStop = i),
    transport: widget.view.request.localTransportMode,
    padding: padding,
  );

  Widget _dayChips() =>
      _DayChips(days: _plan.days, selected: _day, onSelected: _selectDay);

  /// Everything about the trip and the selected day, in reading order:
  /// the cost at a glance, any Over Budget help, the day's timeline, then
  /// the full trip overview.
  List<Widget> _details() {
    final over = _plan.cost.isOverBudget;
    return [
      _CostHeader(view: widget.view),
      if (over) ...[
        const SizedBox(height: 12),
        OverBudgetBanner(
          cost: _plan.cost,
          hasAdvice: _plan.overBudgetAdvice.isNotEmpty,
          canShorten: _plan.days.length > 1,
        ),
        _OverBudgetHelp(tripId: widget.tripId, plan: _plan),
      ],
      const SizedBox(height: 20),
      _DayHeader(
        dayIndex: _day,
        date: _dayPlan.date,
        pace: widget.view.request.pace,
      ),
      const SizedBox(height: 8),
      DayWeatherRow(
        place: widget.view.destination.center,
        start: widget.view.request.startDate,
        end: widget.view.request.endDate,
        date: _dayPlan.date,
      ),
      for (final warning in _dayPlan.warnings) ...[
        const SizedBox(height: 8),
        _DayWarning(warning),
      ],
      const SizedBox(height: 16),
      _timeline(),
      const SizedBox(height: 24),
      _TripSummaryCard(view: widget.view),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sizeClass = context.windowSizeClass;
    final margin = sizeClass.pageMargin;

    final Widget body;
    if (sizeClass.isAtLeast(WindowSizeClass.expanded)) {
      body = Row(
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dayChips(),
                  const SizedBox(height: 16),
                  ..._details(),
                ],
              ),
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
      // Map first: the plan rides in a sheet the traveller drags up to read
      // and down to see more of the map (#182).
      body = LayoutBuilder(
        builder: (context, constraints) {
          const initial = 0.45;
          return Stack(
            children: [
              Positioned.fill(
                child: _map(
                  padding: EdgeInsets.only(
                    top: 56,
                    bottom: constraints.maxHeight * initial,
                  ),
                ),
              ),
              Positioned(
                left: margin,
                right: margin,
                top: 8,
                child: _dayChips(),
              ),
              DraggableScrollableSheet(
                initialChildSize: initial,
                minChildSize: 0.16,
                maxChildSize: 1,
                snap: true,
                snapSizes: const [0.16, initial, 1],
                builder: (context, scroll) => _PlanSheet(
                  controller: scroll,
                  padding: EdgeInsets.fromLTRB(margin, 0, margin, margin),
                  children: _details(),
                ),
              ),
            ],
          );
        },
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
          Consumer(
            builder: (context, ref, _) => MenuAnchor(
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.notes_outlined),
                  onPressed: () => _share(context, ref),
                  child: const Text('แชร์เป็นข้อความ'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.event_available_outlined),
                  onPressed: () => _exportCalendar(context, ref),
                  child: const Text('เพิ่มลงปฏิทิน'),
                ),
              ],
              builder: (context, controller, _) => IconButton(
                icon: const Icon(Icons.ios_share_outlined),
                tooltip: 'แชร์แผน',
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
          ),
          if (widget.view.savedTrip case final trip?) _TripMenu(trip: trip),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: _BottomActions(
        view: widget.view,
        onAskAi: _openChat,
      ),
    );
  }
}

/// A small, non-interactive map of the selected day; tap to open the map.
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
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('ลบทริปแล้ว')));
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

/// Saving the plan (#43) and editing it with the AI chat (#46).
class _BottomActions extends ConsumerStatefulWidget {
  const _BottomActions({required this.view, required this.onAskAi});

  final TripPlanView view;
  final VoidCallback onAskAi;

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
                      onPressed: widget.onAskAi,
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

    final savedId = view.savedTrip?.id;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The Destination's photo, flying in from the trip card when the
          // plan opens from home or ทริปของฉัน.
          Stack(
            children: [
              Positioned.fill(
                child: PlacePhoto(
                  id: plan.destinationId,
                  label: view.destination.name,
                  heroTag: savedId == null ? null : 'trip-$savedId',
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 200),
                child: PhotoScrim(
                  child: Container(
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Builder(
                      builder: (context) {
                        final text = Theme.of(context).textTheme;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.preferenceTags
                                  .map((t) => t.label)
                                  .join(' & '),
                              style: text.labelMedium,
                            ),
                            Text(
                              '${view.destination.name} '
                              '${days == 1 ? '1 วัน' : '$days วัน ${days - 1} คืน'}',
                              style: text.headlineSmall,
                            ),
                            Text(
                              '${formatDateRange(request.startDate, request.endDate)}'
                              ' · ${request.travellerCount} คน',
                              style: text.bodyMedium,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Over Budget is the banner's to say, once.
              if (!cost.isOverBudget)
                const Positioned(
                  left: 16,
                  top: 16,
                  child: _WithinBudgetBadge(),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CostSummaryCard(
                  cost: cost,
                  travellerCount: request.travellerCount,
                ),
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
        ],
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
    final fg = colors.onTertiaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
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

/// A warning about the whole day, such as a dropped Stop (§10.3); styled
/// like the warnings on a Stop.
class _DayWarning extends StatelessWidget {
  const _DayWarning(this.warning);

  final String warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_outlined, size: 16, color: colors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            warning,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
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

/// The draggable sheet over the map on phones: a drag handle, then the
/// plan's details in one scroll.
class _PlanSheet extends StatelessWidget {
  const _PlanSheet({
    required this.controller,
    required this.padding,
    required this.children,
  });

  final ScrollController controller;
  final EdgeInsets padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.shadow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      // One day's plan is short enough to build at once, which keeps every
      // Stop reachable for screen readers.
      child: SingleChildScrollView(
        controller: controller,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// The trip and its Cost Estimate at a glance; tap for the breakdown.
class _CostHeader extends StatelessWidget {
  const _CostHeader({required this.view});

  final TripPlanView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final request = view.request;
    final cost = view.plan.cost;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showCostBreakdownSheet(
        context,
        cost: cost,
        travellerCount: request.travellerCount,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${view.destination.name} '
                    '${formatTripLength(request.startDate, request.endDate)}',
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    '${formatDateRange(request.startDate, request.endDate)}'
                    ' · ${request.travellerCount} คน',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatBaht(cost.total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cost.isOverBudget ? colors.error : colors.primary,
                  ),
                ),
                Text(
                  '${formatBaht(cost.perPerson)} / คน',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
