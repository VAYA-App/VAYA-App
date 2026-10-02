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

/// A Trip Plan shown day by day (#39).
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

class _TripPlanBodyState extends State<_TripPlanBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: widget.view.plan.days.length,
    vsync: this,
  )..addListener(_onDayChanged);

  /// Compact windows show either the timeline or the map.
  var _showMap = false;

  /// Highlighted Stop of the selected day, shared by timeline and map.
  int? _selectedStop;

  void _onDayChanged() {
    if (!_tabs.indexIsChanging) setState(() => _selectedStop = null);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// The Night Stay that ends day [dayIndex], if any (none on the last day).
  NightStay? _nightStayAfter(int dayIndex) {
    for (final stay in widget.view.plan.nightStays) {
      if (stay.night == dayIndex + 1) return stay;
    }
    return null;
  }

  void _selectStop(int dayIndex, int stopIndex) {
    setState(() => _selectedStop = stopIndex);
    final day = widget.view.plan.days[dayIndex];
    final stop = day.stops[stopIndex];
    showStopDetailSheet(
      context,
      number: stopIndex + 1,
      stop: stop,
      place: widget.view.catalog.place(stop.placeId),
      date: day.date,
    );
  }

  Widget _timeline(int dayIndex, double margin) {
    final view = widget.view;
    return ListView(
      padding: EdgeInsets.all(margin),
      children: [
        _TripSummary(view: view),
        const SizedBox(height: 24),
        StopTimeline(
          day: view.plan.days[dayIndex],
          catalog: view.catalog,
          transport: view.request.localTransportMode,
          nightStay: _nightStayAfter(dayIndex),
          selectedIndex: dayIndex == _tabs.index ? _selectedStop : null,
          onSelect: (stop) => _selectStop(dayIndex, stop),
        ),
      ],
    );
  }

  Widget _map(int dayIndex) {
    final view = widget.view;
    return TripMap(
      day: view.plan.days[dayIndex],
      catalog: view.catalog,
      nightStay: _nightStayAfter(dayIndex),
      selectedIndex: dayIndex == _tabs.index ? _selectedStop : null,
      onSelect: (stop) => _selectStop(dayIndex, stop),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final plan = view.plan;
    final sizeClass = context.windowSizeClass;
    final margin = sizeClass.pageMargin;
    final days = [for (var i = 0; i < plan.days.length; i++) i];

    final Widget body;
    if (sizeClass.isAtLeast(WindowSizeClass.expanded)) {
      body = Row(
        children: [
          Expanded(
            flex: 5,
            child: TabBarView(
              controller: _tabs,
              children: [for (final i in days) _timeline(i, margin)],
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, margin, margin, margin),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _map(_tabs.index),
              ),
            ),
          ),
        ],
      );
    } else {
      body = Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(margin, 12, margin, 0),
            child: SizedBox(
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
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              // Map gestures would fight the swipe between days.
              physics: _showMap ? const NeverScrollableScrollPhysics() : null,
              children: [
                for (final i in days)
                  _showMap
                      ? Padding(
                          padding: EdgeInsets.all(margin),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _map(i),
                          ),
                        )
                      : _timeline(i, margin),
              ],
            ),
          ),
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
        title: Text(view.destination.name),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: plan.days.length > 3,
          tabs: [
            for (final (i, day) in plan.days.indexed)
              Tab(text: 'วันที่ ${i + 1} · ${formatThaiShortDate(day.date)}'),
          ],
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}

/// Dates, travellers and a cost summary. The full cost card with its
/// breakdown sheet comes from #36.
class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.view});

  final TripPlanView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = view.request;
    final cost = view.plan.cost;
    final intercity = view.plan.intercity;

    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                '${formatThaiShortDate(request.startDate)} – '
                    '${formatThaiShortDate(request.endDate)}',
                '${request.travellerCount} คน',
                if (intercity != null) intercity.mode.label,
              ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatBaht(cost.total)} / งบ ${formatBaht(cost.budget)}',
              style: theme.textTheme.headlineSmall,
            ),
            Text(
              'ต่อคน ${formatBaht(cost.perPerson)} · ราคาโดยประมาณ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
