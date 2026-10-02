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
    this.issue,
    this.owner,
    this.shortcuts = const [],
  });

  final String screenName;

  /// GitHub issue that builds this screen; `null` for features outside the
  /// current scope.
  final int? issue;
  final String? owner;
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
                switch ((issue, owner)) {
                  (null, _) => 'เร็ว ๆ นี้',
                  (final i?, null) => 'เร็ว ๆ นี้ · ดู issue #$i',
                  (final i?, final o?) =>
                    'หน้านี้ยังไม่ได้ทำ · ดู issue #$i (@$o)',
                },
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
