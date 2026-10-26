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
import '../trip_request/trip_request_form_notifier.dart';
import '../trips/trip_groups.dart';
import 'greeting.dart';
import 'place_picks.dart';

/// หน้าแรก (#172): a greeting, the Upcoming Trip, a way to plan a new one
/// and attractions that fit the traveller's Taste Profile.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final margin = context.windowSizeClass.pageMargin;
    final trips = ref.watch(savedTripsProvider).value ?? const [];
    final upcoming = TripGroups(trips, ref.watch(todayProvider)).upcoming;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: WindowSizeClass.maxContentWidth,
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, 16, margin, 32),
              children: [
                const _Greeting(),
                const SizedBox(height: 20),
                if (upcoming != null) ...[
                  _UpcomingTrip(trip: upcoming),
                  const SizedBox(height: 16),
                ],
                const _PlannerCard(),
                const SizedBox(height: 28),
                const _Picks(),
              ],
            ),
          ),
        ),
      ),
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

/// The Upcoming Trip as a photo card with a countdown.
class _UpcomingTrip extends ConsumerWidget {
  const _UpcomingTrip({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final request = trip.request;
    final province =
        ref
            .watch(placeCatalogProvider)
            .value
            ?.findProvince(trip.plan.destinationId)
            ?.name ??
        trip.plan.destinationId;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: InkWell(
        onTap: trip.id == null
            ? null
            : () => context.push(AppRoutes.tripPlan(trip.id!)),
        // The photo fills the card; the text sets its height, so large
        // text grows the card instead of overflowing it.
        child: Stack(
          children: [
            Positioned.fill(
              // No Hero: ทริปของฉัน, alive in the same shell route, already
              // tags this trip's photo.
              child: PlacePhoto(id: trip.plan.destinationId, label: province),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 220),
              child: PhotoScrim(
                child: Container(
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.fromLTRB(20, 64, 20, 18),
                  child: Builder(
                    builder: (context) {
                      final text = Theme.of(context).textTheme;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ทริปถัดไป', style: text.labelLarge),
                          Text(
                            '$province '
                            '${formatTripLength(request.startDate, request.endDate)}',
                            style: text.headlineSmall,
                          ),
                          Text(
                            '${formatDateRange(request.startDate, request.endDate)}'
                            ' · ${request.travellerCount} คน'
                            ' · ${formatBaht(trip.plan.cost.total)}',
                            style: text.bodyMedium,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    countdownLabel(trip, ref.watch(todayProvider)),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The main way into planning, in the brand colour.
class _PlannerCard extends StatelessWidget {
  const _PlannerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.filled(
      color: colors.primary,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.newTrip),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(Icons.auto_awesome, color: colors.onPrimary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'วางแผนทริปใหม่',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                    Text(
                      'บอกเวลา งบ และสไตล์ ที่เหลือให้ AI',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Attractions that fit the Taste Profile; one tap opens the Place.
class _Picks extends ConsumerWidget {
  const _Picks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final picks = ref.watch(placePicksProvider);
    final catalog = ref.watch(placeCatalogProvider).value;
    final height = 120 + MediaQuery.textScalerOf(context).scale(56);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('เข้ากับสไตล์คุณ', style: theme.textTheme.titleLarge),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: const Text('ดูทั้งหมด'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: switch (picks) {
            AsyncData(:final value) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: value.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => StaggeredEntrance(
                index: i,
                child: _PickCard(
                  place: value[i],
                  province: catalog?.findProvince(value[i].provinceId)?.name,
                ),
              ),
            ),
            AsyncError() => const SizedBox.shrink(),
            _ => ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                Skeleton(width: 168, height: 168, radius: 20),
                SizedBox(width: 12),
                Skeleton(width: 168, height: 168, radius: 20),
              ],
            ),
          },
        ),
      ],
    );
  }
}

class _PickCard extends ConsumerWidget {
  const _PickCard({required this.place, required this.province});

  final Place place;
  final String? province;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 168,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.place(place.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 112,
                child: PlacePhoto(
                  id: place.id,
                  label: place.name,
                  category: place.category,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [?province, ?place.tags.firstOrNull?.label].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
