import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';
import '../../app/router.dart';
import '../../domain/domain.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/mascot_view.dart';
import 'suggestions_provider.dart';

/// จังหวัดที่เหมาะกับคุณ: the provinces that fit the Trip Request, best
/// first, to pick one and generate its plan (#23).
class SuggestionScreen extends ConsumerWidget {
  const SuggestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('จังหวัดที่เหมาะกับคุณ')),
      body: SafeArea(
        child: switch (ref.watch(suggestionsProvider)) {
          AsyncData(value: final view) when view.suggestions.isEmpty => _Message(
            pose: MascotPose.budget,
            title: 'ยังไม่มีจังหวัดที่อยู่ในงบ',
            body:
                'งบ ${formatBaht(view.request.budget)} ยังไม่พอสำหรับ '
                '${view.request.dayCount} วัน ${view.request.travellerCount} คน '
                'ลองเพิ่มงบ ลดจำนวนวัน หรือเลือกเดือนอื่น',
            action: FilledButton.icon(
              onPressed: () => context.go(AppRoutes.newTrip),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('แก้ไขทริป'),
            ),
          ),
          AsyncData(value: final view) => _SuggestionList(view: view),
          AsyncError() => _Message(
            pose: MascotPose.map,
            title: 'หาจังหวัดไม่สำเร็จ',
            body: 'ตรวจสอบการเชื่อมต่อแล้วลองใหม่อีกครั้ง',
            action: FilledButton.tonalIcon(
              onPressed: () => ref.invalidate(suggestionsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ),
          _ => const _Loading(),
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: EdgeInsets.all(context.windowSizeClass.pageMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LinearProgressIndicator(semanticsLabel: 'กำลังหาจังหวัด'),
              const SizedBox(height: 16),
              Text(
                'กำลังหาจังหวัดที่เหมาะกับงบและสไตล์ของคุณ…',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty and error states: the mascot, what happened and one way out.
class _Message extends StatelessWidget {
  const _Message({
    required this.pose,
    required this.title,
    required this.body,
    required this.action,
  });

  final MascotPose pose;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.windowSizeClass.pageMargin),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MascotView(pose: pose, size: 120),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.view});

  final SuggestionsView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeClass = context.windowSizeClass;
    final columns = sizeClass.isAtLeast(WindowSizeClass.large)
        ? 3
        : sizeClass.isAtLeast(WindowSizeClass.expanded)
        ? 2
        : 1;
    final request = view.request;
    final cards = [
      for (final (i, s) in view.suggestions.indexed)
        _SuggestionCard(
          suggestion: s,
          province: view.catalog.province(s.provinceId),
          month: request.startDate,
          recommended: i == 0,
        ),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: columns == 1 ? 600 : 1200),
        child: ListView(
          padding: EdgeInsets.all(sizeClass.pageMargin),
          children: [
            Text(
              '${view.suggestions.length} จังหวัดที่อยู่ในงบ '
              '${formatBaht(request.budget)} สำหรับ ${request.travellerCount} คน',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < cards.length; i += columns) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: 16),
                    Expanded(
                      child: i + col < cards.length
                          ? cards[i + col]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.province,
    required this.month,
    required this.recommended,
  });

  final DestinationSuggestion suggestion;
  final Province province;
  final DateTime month;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final season = province.seasonFor(month.month);

    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recommended) ...[
            Chip(
              avatar: Icon(
                Icons.star_rounded,
                color: colors.onTertiaryContainer,
              ),
              label: const Text('แนะนำ'),
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color: colors.onTertiaryContainer,
              ),
              backgroundColor: colors.tertiaryContainer,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
          ],
          Text(province.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(suggestion.reason, style: theme.textTheme.bodyMedium),
          if (suggestion.highlightTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in suggestion.highlightTags)
                  Chip(
                    label: Text(tag.label),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'เริ่มต้น ~${formatBaht(suggestion.minimumCost)} · '
            '${formatThaiMonth(month)} ${season.label}',
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          Text(
            'ราคาโดยประมาณ ทั้งทริป',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => context.go(
                '${AppRoutes.generating}?destination=${province.id}',
              ),
              child: const Text('เลือกจังหวัดนี้'),
            ),
          ),
        ],
      ),
    );

    return recommended
        ? Card.filled(
            margin: EdgeInsets.zero,
            color: colors.secondaryContainer,
            child: content,
          )
        : Card.outlined(margin: EdgeInsets.zero, child: content);
  }
}
