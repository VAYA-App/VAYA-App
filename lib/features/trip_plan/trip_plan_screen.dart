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
  );

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

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final plan = view.plan;
    final margin = context.windowSizeClass.pageMargin;

    return Scaffold(
      appBar: AppBar(
        leading: context.canPop()
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
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: [
            for (final (i, day) in plan.days.indexed)
              ListView(
                padding: EdgeInsets.all(margin),
                children: [
                  _TripSummary(view: view),
                  const SizedBox(height: 24),
                  StopTimeline(
                    day: day,
                    catalog: view.catalog,
                    transport: view.request.localTransportMode,
                    nightStay: _nightStayAfter(i),
                    onSelect: (stopIndex) => showStopDetailSheet(
                      context,
                      number: stopIndex + 1,
                      stop: day.stops[stopIndex],
                      place: view.catalog.place(day.stops[stopIndex].placeId),
                      date: day.date,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
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
