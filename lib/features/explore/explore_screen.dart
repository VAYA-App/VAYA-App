import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/providers/data_providers.dart';
import 'trip_ideas.dart';
import 'widgets/trip_idea_artwork.dart';
import 'widgets/trip_idea_card.dart';

/// Trip ideas to browse (#84): a hero carousel plus the same ideas as a
/// plain list, so nothing needs a swipe to reach.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('สำรวจ')),
      body: switch (ref.watch(tripIdeasProvider)) {
        AsyncData(:final value) => _Ideas(ideas: value),
        AsyncError() => _LoadError(
          onRetry: () => ref.invalidate(tripIdeasProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Ideas extends ConsumerWidget {
  const _Ideas({required this.ideas});

  final List<TripIdea> ideas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = context.windowSizeClass;
    final provinces = ref.watch(placeCatalogProvider).value;
    // Room for the artwork plus the card text at the user's font size.
    final height = 180 + MediaQuery.textScalerOf(context).scale(110);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: WindowSizeClass.maxContentWidth,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(size.pageMargin, 8, size.pageMargin, 32),
          children: [
            Text('ไอเดียทริป', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'แตะไอเดียที่ชอบ แล้วเราจะเลือกจังหวัดและสไตล์ไว้ให้',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: CarouselView.weighted(
                flexWeights: size == WindowSizeClass.compact
                    ? const [7, 1]
                    : const [4, 4, 1],
                itemSnapping: true,
                onTap: (i) => openTripIdea(context, ref, ideas[i]),
                children: [for (final idea in ideas) TripIdeaCard(idea: idea)],
              ),
            ),
            const SizedBox(height: 32),
            Text('ทุกไอเดีย', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final idea in ideas)
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox.square(
                          dimension: 56,
                          child: TripIdeaArtwork(art: idea.art),
                        ),
                      ),
                      title: Text(idea.title),
                      subtitle: Text(
                        tripIdeaMeta(
                          idea,
                          provinces?.findProvince(idea.provinceId)?.name,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openTripIdea(context, ref, idea),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ไอเดียตัวอย่างจากทีม VAYA · ราคาโดยประมาณต่อคนทั้งทริป',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text('โหลดไอเดียทริปไม่สำเร็จ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
