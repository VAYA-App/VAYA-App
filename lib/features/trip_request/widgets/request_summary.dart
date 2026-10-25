import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers/data_providers.dart';
import '../../../shared/formatters.dart';
import '../trip_request_form_notifier.dart';

/// The whole Trip Request at a glance, on the last step, so the traveller
/// checks it before the AI plans (#170). Each row jumps back to its step.
class RequestSummary extends ConsumerWidget {
  const RequestSummary({super.key, required this.onEdit});

  final ValueChanged<TripRequestStep> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final form = ref.watch(tripRequestFormProvider);
    final places = ref.watch(placeCatalogProvider).value;
    String province(String id) => places?.findProvince(id)?.name ?? id;

    final start = form.startDate, end = form.endDate, budget = form.budget;
    final transport = [
      if (form.needsIntercity) form.intercityMode.label,
      form.localTransportMode.label,
    ].join(' · ');

    return Card.filled(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('สรุปคำขอ', style: theme.textTheme.titleMedium),
            ),
            _Row(
              icon: Icons.route_outlined,
              label: 'เส้นทาง',
              value:
                  '${province(form.originId)} → '
                  '${form.destinationId == null ? 'ให้ AI เลือก' : province(form.destinationId!)}',
              onEdit: () => onEdit(TripRequestStep.routeAndDates),
            ),
            _Row(
              icon: Icons.calendar_month_outlined,
              label: 'วันที่',
              value: start != null && end != null
                  ? '${formatDateRange(start, end)} · ${form.travellerCount} คน'
                  : '${form.travellerCount} คน',
              onEdit: () => onEdit(TripRequestStep.routeAndDates),
            ),
            _Row(
              icon: Icons.payments_outlined,
              label: 'งบรวม',
              value: budget == null
                  ? '-'
                  : '${formatBaht(budget)} '
                        '(${formatBaht((budget / form.travellerCount).round())} / คน)',
              onEdit: () => onEdit(TripRequestStep.budgetAndPace),
            ),
            _Row(
              icon: Icons.speed_outlined,
              label: 'จังหวะ · เดินทาง',
              value: '${form.pace.label} · $transport',
              onEdit: () => onEdit(TripRequestStep.budgetAndPace),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      onTapHint: 'แก้ไข$label',
      child: ListTile(
        leading: Icon(icon, color: colors.primary),
        title: Text(label),
        subtitle: Text(value),
        subtitleTextStyle: Theme.of(context).textTheme.bodyLarge,
        trailing: Icon(Icons.edit_outlined, color: colors.onSurfaceVariant),
        onTap: onEdit,
      ),
    );
  }
}
