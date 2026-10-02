import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';

/// Temporary body for screens that are not built yet.
///
/// Shows which GitHub issue owns the screen and offers shortcuts so the
/// whole flow stays navigable during development. Delete it from a screen
/// as soon as that screen's issue lands.
class NotImplementedView extends StatelessWidget {
  const NotImplementedView({
    super.key,
    required this.screenName,
    required this.issue,
    required this.owner,
    this.shortcuts = const [],
  });

  final String screenName;
  final int issue;
  final String owner;
  final List<({String label, String location})> shortcuts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeClass = context.windowSizeClass;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: WindowSizeClass.maxContentWidth,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(sizeClass.pageMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                screenName,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'หน้านี้ยังไม่ได้ทำ · ดู issue #$issue (@$owner)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in shortcuts)
                    FilledButton.tonal(
                      onPressed: () => context.go(s.location),
                      child: Text(s.label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
