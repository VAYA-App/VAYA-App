import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';

/// Opens the Cost Estimate split by category as a modal bottom sheet.
Future<void> showCostBreakdownSheet(
  BuildContext context, {
  required CostEstimate cost,
  required int travellerCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _CostBreakdown(cost: cost, travellerCount: travellerCount),
  );
}

class _CostBreakdown extends StatelessWidget {
  const _CostBreakdown({required this.cost, required this.travellerCount});

  final CostEstimate cost;
  final int travellerCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final amount = theme.textTheme.titleMedium;
    // Every category is listed, also at ฿0, so nothing looks forgotten.
    final categories = [
      (Icons.directions_bus_outlined, 'เดินทางข้ามเมือง', cost.intercity),
      (Icons.bed_outlined, 'ที่พัก', cost.accommodation),
      (Icons.restaurant_outlined, 'อาหาร', cost.food),
      (Icons.confirmation_number_outlined, 'ค่าเข้าชม', cost.entrance),
      (Icons.local_taxi_outlined, 'เดินทางในพื้นที่', cost.localTransport),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'รายละเอียดค่าใช้จ่าย',
                style: theme.textTheme.titleLarge,
              ),
            ),
            for (final (icon, label, baht) in categories)
              ListTile(
                leading: Icon(icon, color: colors.primary),
                title: Text(label),
                trailing: Text(formatBaht(baht), style: amount),
              ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              title: const Text('ค่าใช้จ่ายจริง'),
              trailing: Text(
                formatBaht(cost.total - cost.buffer),
                style: amount,
              ),
            ),
            ListTile(
              leading: Icon(Icons.savings_outlined, color: colors.tertiary),
              title: const Text('เงินสำรอง'),
              subtitle: const Text('เผื่อค่าใช้จ่ายที่ไม่คาดคิด'),
              trailing: Text(formatBaht(cost.buffer), style: amount),
            ),
            ListTile(
              title: Text('รวมทั้งหมด', style: theme.textTheme.titleMedium),
              trailing: Text(
                formatBaht(cost.total),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cost.isOverBudget ? colors.error : colors.primary,
                ),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              title: const Text('งบที่ตั้งไว้'),
              trailing: Text(formatBaht(cost.budget), style: amount),
            ),
            ListTile(
              title: Text('เฉลี่ยต่อคน ($travellerCount ท่าน)'),
              trailing: Text(
                formatBaht(cost.perPerson),
                style: amount?.copyWith(color: colors.tertiary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'ราคาโดยประมาณ อาจต่างจากราคาจริง',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
