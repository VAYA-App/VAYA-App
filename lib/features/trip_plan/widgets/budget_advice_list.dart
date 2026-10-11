import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../../../planner/default_over_budget_advisor.dart';
import '../../../shared/formatters.dart';

/// The ways to bring an Over Budget plan back, one card each (#38).
class BudgetAdviceList extends StatelessWidget {
  const BudgetAdviceList({super.key, required this.advice});

  final List<BudgetAdvice> advice;

  static IconData _iconFor(BudgetAdviceKind kind) => switch (kind) {
    BudgetAdviceKind.downgradeAccommodation => Icons.bed_outlined,
    BudgetAdviceKind.changeLocalTransport => Icons.commute_outlined,
    BudgetAdviceKind.removeDay => Icons.event_busy_outlined,
    BudgetAdviceKind.changeDestination => Icons.map_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('วิธีลดค่าใช้จ่าย', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in advice) ...[
          Card.outlined(
            child: ListTile(
              leading: Icon(_iconFor(item.kind), color: colors.primary),
              title: Text(item.description),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'แต่ละวิธีคิดแยกกัน ยอดประหยัดนำมารวมกันไม่ได้ · ราคาโดยประมาณ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Shown when every option together still leaves the plan Over Budget. It
/// leads with how far over the plan stays, then the budget this trip needs
/// or how short it would have to be. With no option to apply, what is left
/// is the amount the banner already gave, so the card does not repeat it.
///
/// The figures from [BudgetRescue] are the cheapest any trip here could be,
/// not this plan made cheaper, and the card says so. When that cheapest
/// trip already fits [budget], naming it would tell the user to have less
/// than they do, so the card only says how much more this plan needs.
class BudgetRescueCard extends StatelessWidget {
  const BudgetRescueCard({
    super.key,
    required this.rescue,
    required this.advice,
    required this.dayCount,
    required this.budget,
  });

  final BudgetRescue rescue;

  /// The options listed above the card, so it claims no more than they do.
  final List<BudgetAdvice> advice;

  /// Days of the trip as planned.
  final int dayCount;

  /// The Budget the plan was priced against.
  final int budget;

  /// [BudgetRescue.stillOverBy] comes from the priced options only; another
  /// province is an estimate the rescue never applies.
  Iterable<BudgetAdvice> get _priced =>
      advice.where((item) => item.kind != BudgetAdviceKind.changeDestination);

  String get _title {
    final priced = _priced;
    if (priced.isEmpty) return 'ระบบยังหาวิธีลดค่าใช้จ่ายของแผนนี้ให้ไม่ได้';
    final stillOver = formatBaht(rescue.stillOverBy);
    return priced.length < advice.length
        ? 'ทำทุกวิธีข้างบนพร้อมกัน ยกเว้นเปลี่ยนจังหวัด '
              'ยังเกินงบอีก $stillOver'
        : 'ทำทุกวิธีข้างบนพร้อมกันแล้วยังเกินงบอีก $stillOver';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = colors.onTertiaryContainer;
    final body = theme.textTheme.bodyMedium?.copyWith(color: foreground);
    final needsBiggerBudget = rescue.minimumBudget > budget;

    return Card.filled(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.savings_outlined, color: foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (needsBiggerBudget) ...[
              Text(
                'ควรมีงบอย่างน้อย ${formatBaht(rescue.minimumBudget)} '
                'สำหรับทริป $dayCount วัน',
                style: body,
              ),
              const SizedBox(height: 6),
              if (rescue.daysThatFit case final days?)
                Text(
                  'หรือลดเหลือ $days วันแบบประหยัดสุด เริ่มต้น '
                  '~${formatBaht(rescue.costOfDaysThatFit ?? 0)}',
                  style: body,
                )
              else if (dayCount > 1)
                Text('งบนี้ยังไม่พอแม้เป็นทริป 1 วัน', style: body),
              const SizedBox(height: 6),
              Text(
                'ตัวเลขขั้นต่ำคิดจากที่พักและอาหารราคาประหยัดสุด '
                'แผนจริงอาจสูงกว่านี้',
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ] else
              Text(
                _priced.isEmpty
                    ? 'ลองเพิ่มงบ หรือเลือกร้านอาหารและที่เที่ยวที่ราคาต่ำลง'
                    : 'ลองเพิ่มงบอีกราว ${formatBaht(rescue.stillOverBy)} '
                          'หรือเลือกที่พักและร้านอาหารที่ราคาต่ำลง',
                style: body,
              ),
          ],
        ),
      ),
    );
  }
}
