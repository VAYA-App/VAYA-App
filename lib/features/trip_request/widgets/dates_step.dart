import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/formatters.dart';
import '../trip_request_form_notifier.dart';
import 'step_section.dart';

/// Step ①: travel dates and Traveller Count.
class DatesStep extends ConsumerWidget {
  const DatesStep({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final form = ref.watch(tripRequestFormProvider);
    final notifier = ref.read(tripRequestFormProvider.notifier);
    final start = form.startDate, end = form.endDate;
    final count = form.travellerCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepSection(
          title: 'วันเดินทาง',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDates(context, ref),
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  start != null && end != null
                      ? '${formatThaiShortDate(start)} – ${formatThaiShortDate(end)}'
                      : 'เลือกวันไป–กลับ',
                ),
              ),
              if (start != null && end != null) ...[
                const SizedBox(height: 8),
                Text(
                  _durationLabel(end.difference(start).inDays + 1),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        StepSection(
          title: 'จำนวนผู้เดินทาง',
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: count > 1
                    ? () => notifier.setTravellerCount(count - 1)
                    : null,
                icon: const Icon(Icons.remove),
                tooltip: 'ลดจำนวนผู้เดินทาง',
              ),
              Expanded(
                child: Text(
                  '$count คน',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton.filledTonal(
                onPressed: count < TripRequestFormState.maxTravellers
                    ? () => notifier.setTravellerCount(count + 1)
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

  static String _durationLabel(int days) =>
      days == 1 ? 'ไปเช้าเย็นกลับ (1 วัน)' : '$days วัน ${days - 1} คืน';
}
