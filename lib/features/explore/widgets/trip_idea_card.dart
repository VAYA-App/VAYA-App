import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers/data_providers.dart';
import '../../../shared/formatters.dart';
import '../trip_ideas.dart';
import 'trip_idea_artwork.dart';

/// "ชลบุรี · 2 วัน · ~฿2,500/คน" for [idea].
String tripIdeaMeta(TripIdea idea, String? provinceName) => [
  ?provinceName,
  '${idea.days} วัน',
  '~${formatBaht(idea.budgetPerPerson)}/คน',
].join(' · ');

/// Body of a carousel item: artwork on top, title and facts below. When the
/// carousel squeezes the item, only the artwork is shown.
class TripIdeaCard extends ConsumerWidget {
  const TripIdeaCard({super.key, required this.idea, this.showSummary = true});

  final TripIdea idea;
  final bool showSummary;

  /// Narrower than this, the text would wrap letter by letter.
  static const _minTextWidth = 160.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final province = ref
        .watch(placeCatalogProvider)
        .whenData((c) => c.findProvince(idea.provinceId)?.name)
        .value;

    return ColoredBox(
      color: colors.surfaceContainerLowest,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final art = TripIdeaArtwork(art: idea.art);
          if (constraints.maxWidth < _minTextWidth) return art;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: art),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idea.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tripIdeaMeta(idea, province),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showSummary) ...[
                      const SizedBox(height: 6),
                      Text(
                        idea.summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
