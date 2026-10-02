import 'package:material_ui/material_ui.dart';

/// A single-choice option drawn as a tappable card: icon, label and an
/// optional caption. Selected cards get the emerald tint and outline.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.caption,
    this.vertical = false,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  /// Stacks icon over text, for short options shown three in a row.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final iconColor = selected ? colors.primary : colors.onSurfaceVariant;

    final text = Column(
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: selected ? colors.onSecondaryContainer : colors.onSurface,
          ),
          textAlign: vertical ? TextAlign.center : TextAlign.start,
        ),
        if (caption != null)
          Text(
            caption!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: vertical ? TextAlign.center : TextAlign.start,
          ),
      ],
    );

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected
            ? colors.secondaryContainer
            : colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: vertical
                ? Column(
                    children: [
                      Icon(icon, color: iconColor),
                      const SizedBox(height: 8),
                      text,
                    ],
                  )
                : Row(
                    children: [
                      Icon(icon, color: iconColor),
                      const SizedBox(width: 12),
                      Expanded(child: text),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Lays out [OptionCard]s in equal-width columns.
class OptionGrid extends StatelessWidget {
  const OptionGrid({super.key, required this.children, this.columns = 2});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
