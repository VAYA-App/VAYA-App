import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/formatters.dart';
import '../../../shared/widgets/motion.dart';
import '../trip_request_form_notifier.dart';
import 'form_section.dart';

/// Travel dates and Traveller Count, on step ① of the form.
class DatesSection extends ConsumerWidget {
  const DatesSection({super.key});

  Future<void> _pickDates(BuildContext context, WidgetRef ref) async {
    final form = ref.read(tripRequestFormProvider);
    final today = ref.read(todayProvider);
    final start = form.startDate, end = form.endDate;
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: start != null && end != null && !start.isBefore(today)
          ? DateTimeRange(start: start, end: end)
          : null,
      helpText: 'เลือกวันไปและวันกลับ',
      saveText: 'ตกลง',
    );
    if (range != null) {
      ref
          .read(tripRequestFormProvider.notifier)
          .setDates(range.start, range.end);
    }
  }

  static String _durationLabel(int days) =>
      days == 1 ? 'ไปเช้าเย็นกลับ' : '$days วัน ${days - 1} คืน';

  static String _groupLabel(int count) => switch (count) {
    1 => 'เที่ยวคนเดียว',
    2 => 'คู่รัก / เพื่อน',
    <= 4 => 'กลุ่มเล็ก',
    _ => 'กลุ่มใหญ่',
  };

  void _setCount(TripRequestFormNotifier notifier, int count) {
    Haptics.select();
    notifier.setTravellerCount(count);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);
    final start = form.startDate, end = form.endDate;
    final count = form.travellerCount;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          icon: Icons.calendar_month_outlined,
          title: 'ช่วงเวลาเดินทาง',
          child: start != null && end != null
              ? InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pickDates(context, ref),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatThaiShortDate(start)} – ${formatThaiShortDate(end)}',
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(
                              _durationLabel(end.difference(start).inDays + 1),
                              style: muted,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => _pickDates(context, ref),
                        icon: const Icon(Icons.edit_calendar_outlined),
                        tooltip: 'เปลี่ยนวันเดินทาง',
                      ),
                    ],
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () => _pickDates(context, ref),
                  icon: const Icon(Icons.date_range_outlined),
                  label: const Text('เลือกวันไป–กลับ'),
                ),
        ),
        FormSection(
          icon: Icons.group_outlined,
          title: 'ผู้เดินทาง',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$count คน', style: theme.textTheme.titleLarge),
                    Text(_groupLabel(count), style: muted),
                  ],
                ),
              ),
              IconButton.outlined(
                onPressed: count > 1
                    ? () => _setCount(notifier, count - 1)
                    : null,
                icon: const Icon(Icons.remove),
                tooltip: 'ลดจำนวนผู้เดินทาง',
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: count < TripRequestFormState.maxTravellers
                    ? () => _setCount(notifier, count + 1)
                    : null,
                icon: const Icon(Icons.add),
                tooltip: 'เพิ่มจำนวนผู้เดินทาง',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
