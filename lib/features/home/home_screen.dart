import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/router.dart';
import '../../shared/widgets/theme_picker_sheet.dart';
import '../explore/trip_ideas.dart';
import '../explore/widgets/trip_idea_card.dart';

/// ทริปของฉัน. Layout skeleton in the Stitch style; the saved trips list
/// and its empty/delete states are built in #42.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final margin = context.windowSizeClass.pageMargin;

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
                const _Brand(),
                const SizedBox(height: 32),
                Text('สวัสดี', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'พร้อมออกเดินทางครั้งต่อไปหรือยัง?',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                const _PlannerCard(),
                const SizedBox(height: 32),
                const _Inspiration(),
                const SizedBox(height: 32),
                Text('ทริปที่บันทึกไว้', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                const _EmptyTrips(),
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
        Column(
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
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.palette_outlined),
          tooltip: 'เปลี่ยนธีม',
          onPressed: () => showThemePicker(context),
        ),
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
                Text(
                  'AI SMART PLANNER',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    letterSpacing: 1,
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
            Icon(Icons.luggage_outlined, size: 40, color: colors.outline),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีทริปที่บันทึกไว้',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'แผนที่คุณบันทึกจะแสดงที่นี่ (กำลังพัฒนา · #42)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
