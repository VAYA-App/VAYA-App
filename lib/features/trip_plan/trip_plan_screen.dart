import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/router.dart';
import '../../domain/domain.dart';
import '../../shared/formatters.dart';
import 'trip_plan_view_provider.dart';
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
      AsyncData(value: final view?) => _TripPlanBody(view: view),
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
  const _TripPlanBody({required this.view});

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
    final summary = _TripSummaryCard(view: widget.view);
    final dayHeader = _DayHeader(
      dayIndex: _day,
      date: _dayPlan.date,
      pace: widget.view.request.pace,
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
                summary,
                const SizedBox(height: 20),
                _dayChips(),
                const SizedBox(height: 20),
                dayHeader,
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
                summary,
                const SizedBox(height: 20),
                toggle,
                const SizedBox(height: 12),
                _dayChips(),
                const SizedBox(height: 20),
                dayHeader,
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
      ),
      body: SafeArea(child: body),
    );
  }
}

/// Trip name, budget status, totals and accommodation (Stitch summary).
/// The per-category breakdown sheet comes from #36.
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
                const SizedBox(width: 8),
                _BudgetBadge(cost: cost),
              ],
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('งบประมาณรวมทั้งทริป', style: muted),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: formatBaht(cost.total),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(color: colors.primary),
                                ),
                                TextSpan(
                                  text: ' / ${formatBaht(cost.budget)}',
                                  style: muted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'เฉลี่ยต่อคน (${request.travellerCount} ท่าน)',
                          style: muted,
                        ),
                        Text(
                          formatBaht(cost.perPerson),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
            const SizedBox(height: 4),
            Text('ราคาโดยประมาณ', style: muted),
          ],
        ),
      ),
    );
  }
}

class _BudgetBadge extends StatelessWidget {
  const _BudgetBadge({required this.cost});

  final CostEstimate cost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final over = cost.isOverBudget;
    final (bg, fg) = over
        ? (colors.errorContainer, colors.onErrorContainer)
        : (colors.secondaryContainer, colors.onSecondaryContainer);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              over ? Icons.warning_amber_outlined : Icons.check_circle_outline,
              size: 16,
              color: fg,
            ),
            const SizedBox(width: 4),
            Text(
              over ? 'เกินงบ ${formatBaht(cost.overBy)}' : 'อยู่ในงบ',
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
