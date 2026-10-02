import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/layout/window_size_class.dart';

/// Friendly body for screens that are not built yet.
///
/// Names the GitHub issue that owns the screen (when there is one) and
/// offers shortcuts so the whole flow stays navigable during development.
class NotImplementedView extends StatelessWidget {
  const NotImplementedView({
    super.key,
    required this.screenName,
    this.issue,
    this.owner,
    this.icon = Icons.hourglass_empty_rounded,
    this.shortcuts = const [],
  });

  final String screenName;

  /// GitHub issue that builds this screen; `null` for features outside the
  /// current scope.
  final int? issue;
  final String? owner;
  final IconData icon;
  final List<({String label, String location})> shortcuts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.windowSizeClass.pageMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 88,
                  child: Icon(
                    icon,
                    size: 40,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                  (final i?, final o?) => 'กำลังพัฒนา · issue #$i (@$o)',
                },
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (shortcuts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in shortcuts)
                      OutlinedButton(
                        onPressed: () => context.go(s.location),
                        child: Text(s.label),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
