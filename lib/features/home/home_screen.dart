import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import '../../app/router.dart';
import '../../domain/domain.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/mascot_view.dart';
import '../../shared/widgets/theme_picker_sheet.dart';
import '../explore/trip_ideas.dart';
import '../explore/widgets/trip_idea_card.dart';
import 'greeting.dart';

/// ทริปของฉัน. Layout skeleton in the Stitch style; the saved trips list
/// and its empty/delete states are built in #42.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final margin = context.windowSizeClass.pageMargin;
    final trips = ref.watch(savedTripsProvider).value ?? const [];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newTrip),
        icon: const Icon(Icons.add),
        label: const Text('วางแผนทริปใหม่'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: WindowSizeClass.maxContentWidth,
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, 16, margin, 96),
              children: [
                const _Brand(),
                const SizedBox(height: 24),
                const _Greeting(),
                const SizedBox(height: 24),
                const _PlannerCard(),
                const SizedBox(height: 32),
                const _Inspiration(),
                const SizedBox(height: 32),
                Text('ทริปที่บันทึกไว้', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                if (trips.isEmpty)
                  const _EmptyTrips()
                else
                  _SavedTrips(trips: trips),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox.square(
            dimension: 40,
            child: Icon(Icons.explore, color: colors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI TRIP PLANNER',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  letterSpacing: 1,
                ),
              ),
              Text('VAYA', style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.palette_outlined),
          tooltip: 'เปลี่ยนธีม',
          onPressed: () => showThemePicker(context),
        ),
      ],
    );
  }
}

/// Time-of-day greeting with the mascot waving hello (#80).
class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final greeting = greetingFor(ref.watch(greetingClockProvider));
    // Large text on a phone needs the whole width for the greeting.
    final showMascot =
        context.windowSizeClass != WindowSizeClass.compact ||
        MediaQuery.textScalerOf(context).scale(1) < 1.5;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting.title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                greeting.subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (showMascot) ...[
          const SizedBox(width: 12),
          const MascotView(pose: MascotPose.wave, size: 112),
        ],
      ],
    );
  }
}

class _PlannerCard extends StatelessWidget {
  const _PlannerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      color: colors.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'AI SMART PLANNER',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'วางแผนทริปใหม่ด้วย AI',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'บอกแค่งบและเวลา ที่เหลือให้ AI จัดเส้นทางที่ใช่ให้คุณ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.newTrip),
              icon: const Icon(Icons.arrow_forward),
              iconAlignment: IconAlignment.end,
              label: const Text('เริ่มวางแผนทริป'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A peek at the trip ideas on Explore (#84).
class _Inspiration extends ConsumerWidget {
  const _Inspiration();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideas = ref.watch(tripIdeasProvider).value;
    if (ideas == null || ideas.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('แรงบันดาลใจ', style: theme.textTheme.titleLarge),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: const Text('ดูทั้งหมด'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150 + MediaQuery.textScalerOf(context).scale(64),
          child: CarouselView(
            itemExtent: 240,
            shrinkExtent: 160,
            itemSnapping: true,
            onTap: (i) => openTripIdea(context, ref, ideas[i]),
            children: [
              for (final idea in ideas)
                TripIdeaCard(idea: idea, showSummary: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Icon(Icons.luggage_outlined, size: 48, color: colors.outline),
            const SizedBox(height: 12),
            Text('ยังไม่มีทริป', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'แผนที่คุณบันทึกจะแสดงที่นี่',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.newTrip),
              icon: const Icon(Icons.add),
              label: const Text('เริ่มวางแผนทริปแรก'),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => context.push('/trips/mock'),
              icon: const Icon(Icons.map_outlined),
              label: const Text('ดูแผนตัวอย่าง'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedTrips extends ConsumerWidget {
  const _SavedTrips({required this.trips});

  final List<Trip> trips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(placeCatalogProvider).value;
    final windowSize = context.windowSizeClass;

    if (windowSize == WindowSizeClass.compact) {
      return Column(
        children: [
          for (final trip in trips) ...[
            _TripCard(trip: trip, catalog: catalog),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    final crossAxisCount = windowSize.index >= WindowSizeClass.expanded.index
        ? 3
        : 2;
    final rows = <Widget>[];
    for (var i = 0; i < trips.length; i += crossAxisCount) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < crossAxisCount; col++) ...[
              if (col > 0) const SizedBox(width: 12),
              Expanded(
                child: i + col < trips.length
                    ? _TripCard(trip: trips[i + col], catalog: catalog)
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip, required this.catalog});

  final Trip trip;
  final PlaceCatalog? catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tripRepo = ref.read(tripRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final province =
        catalog?.findProvince(trip.plan.destinationId)?.name ??
        trip.plan.destinationId;
    final dateRange = formatDateRange(
      trip.request.startDate,
      trip.request.endDate,
    );
    final cost = trip.plan.cost;

    return Dismissible(
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
        if (trip.id != null) {
          tripRepo.deleteTrip(trip.id!);
        }
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('ลบทริป$provinceแล้ว'),
            action: SnackBarAction(
              label: 'เลิกทำ',
              onPressed: () {
                tripRepo.saveTrip(trip);
              },
            ),
          ),
        );
      },
      child: Card.outlined(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: trip.id != null
              ? () => context.push(AppRoutes.tripPlan(trip.id!))
              : null,
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                province,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (cost.isOverBudget)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          size: 14,
                          color: colors.onErrorContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'เกินงบ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                '$dateRange · ${trip.request.travellerCount} คน',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatBaht(cost.total),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cost.isOverBudget ? colors.error : colors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ราคาโดยประมาณ',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
