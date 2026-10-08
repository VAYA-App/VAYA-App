import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';
import 'cost_breakdown_sheet.dart';

/// The Cost Estimate against the Budget, with the share already spent.
/// Tapping it opens the breakdown by category (#36).
class CostSummaryCard extends StatelessWidget {
  const CostSummaryCard({
    super.key,
    required this.cost,
    required this.travellerCount,
  });

  final CostEstimate cost;
  final int travellerCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final over = cost.isOverBudget;
    // No Budget to compare with: leave the bar out.
    final spent = cost.budget > 0 ? cost.total / cost.budget : null;

    return Card.filled(
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCostBreakdownSheet(
          context,
          cost: cost,
          travellerCount: travellerCount,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    Text('งบประมาณรวมทั้งทริป', style: muted),
                    Text('ราคาโดยประมาณ', style: muted),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatBaht(cost.total),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: over ? colors.error : colors.primary,
                      ),
                    ),
                    TextSpan(
                      text: ' / งบ ${formatBaht(cost.budget)}',
                      style: muted,
                    ),
                  ],
                ),
              ),
              if (spent != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: spent.clamp(0, 1).toDouble(),
                        color: over ? colors.error : colors.primary,
                        backgroundColor: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                        minHeight: 8,
                        semanticsLabel: 'ใช้ไปเทียบกับงบ',
                        // Semantics accept 0–100% only; the text beside the bar
                        // carries the real share when over budget.
                        semanticsValue: '${(spent.clamp(0, 1) * 100).round()}%',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(spent * 100).round()}% ของงบ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: over ? colors.error : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'เฉลี่ยต่อคน ($travellerCount ท่าน) ',
                            style: muted,
                          ),
                          TextSpan(
                            text: formatBaht(cost.perPerson),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'ดูรายละเอียด',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: colors.primary),
                      ],
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
