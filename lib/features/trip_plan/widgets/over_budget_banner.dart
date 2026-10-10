import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/mascot_view.dart';

/// Says how far an Over Budget plan is over, in words and with an icon
/// (#38). When only the buffer pushes it over, the tone is softer.
class OverBudgetBanner extends StatelessWidget {
  const OverBudgetBanner({
    super.key,
    required this.cost,
    this.hasAdvice = true,
    this.canShorten = true,
  });

  final CostEstimate cost;

  /// Whether ways to save money are listed further down the screen.
  final bool hasAdvice;

  /// Whether the trip has a day to give up; a day trip does not.
  final bool canShorten;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final realCost = cost.total - cost.buffer;
    final onlyBuffer = realCost <= cost.budget;
    final (background, foreground) = onlyBuffer
        ? (colors.tertiaryContainer, colors.onTertiaryContainer)
        : (colors.errorContainer, colors.onErrorContainer);
    // Large text needs the whole width (docs/MASCOT.md).
    final showMascot = MediaQuery.textScalerOf(context).scale(1) < 1.5;

    final String title;
    final String body;
    if (onlyBuffer) {
      title = 'เกินงบ ${formatBaht(cost.overBy)} เพราะเงินสำรอง';
      body =
          'ค่าใช้จ่ายจริง ${formatBaht(realCost)} ไม่เกินงบ '
          'ส่วนที่เกินมาจากเงินสำรอง ${formatBaht(cost.buffer)}';
    } else {
      title = 'เกินงบ ${formatBaht(cost.overBy)}';
      body = hasAdvice
          ? 'ยังแสดงแผนให้ครบ ดูวิธีลดค่าใช้จ่ายด้านล่าง'
          : canShorten
          ? 'ยังแสดงแผนให้ครบ ลองเพิ่มงบหรือลดจำนวนวันดู'
          : 'ยังแสดงแผนให้ครบ ลองเพิ่มงบดู';
    }

    return Semantics(
      container: true,
      child: Card.filled(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          onlyBuffer
                              ? Icons.info_outline
                              : Icons.warning_amber_outlined,
                          color: foreground,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
              if (showMascot) ...[
                const SizedBox(width: 12),
                const MascotView(pose: MascotPose.budget, size: 76),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
