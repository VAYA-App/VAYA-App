import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';
import 'stop_timeline.dart';

/// Opens the details of one Stop as a modal bottom sheet.
Future<void> showStopDetailSheet(
  BuildContext context, {
  required int number,
  required Stop stop,
  required Place place,
  required DateTime date,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _StopDetail(number: number, stop: stop, place: place, date: date),
  );
}

class _StopDetail extends StatelessWidget {
  const _StopDetail({
    required this.number,
    required this.stop,
    required this.place,
    required this.date,
  });

  final int number;
  final Stop stop;
  final Place place;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hours = place.hoursOn(date);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'จุดที่ $number · ${stop.slot.label}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(place.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              place.shortDescription,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: categoryIcon(place.category),
              label: [place.category.label, ?place.area].join(' · '),
            ),
            _DetailRow(
              icon: Icons.schedule_outlined,
              label:
                  '${stop.start.toJson()}–${stop.end.toJson()} '
                  '(${formatMinutes(stop.durationMin)})',
            ),
            _DetailRow(
              icon: Icons.door_front_door_outlined,
              label: !place.hasKnownOpeningHours
                  ? 'ไม่มีข้อมูลเวลาเปิด-ปิด'
                  : hours == null
                  ? 'ปิดวันนี้'
                  : 'เปิด ${hours.open.toJson()}–${hours.close.toJson()}',
            ),
            _DetailRow(
              icon: Icons.payments_outlined,
              label: stop.cost == 0
                  ? 'ไม่มีค่าใช้จ่าย'
                  : '${formatBaht(stop.cost)} (ราคาโดยประมาณ)',
            ),
            if (place.rating != null)
              _DetailRow(
                icon: Icons.star_outline,
                label: 'คะแนน ${place.rating!.toStringAsFixed(1)}',
              ),
            if (stop.note != null) ...[
              const SizedBox(height: 16),
              Card.filled(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('ทำไมถึงเลือกที่นี่'),
                  subtitle: Text(stop.note!),
                ),
              ),
            ],
            for (final warning in stop.warnings) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.warning_amber_outlined,
                label: warning,
                color: colors.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: c),
            ),
          ),
        ],
      ),
    );
  }
}
