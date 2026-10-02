import 'package:material_ui/material_ui.dart';

import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/coming_soon.dart';
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
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryPill(category: place.category),
                const SizedBox(width: 8),
                Text(
                  'จุดที่ $number · ${stop.slot.label}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(place.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (place.rating case final rating?) ...[
                  Icon(Icons.star_rounded, size: 18, color: colors.tertiary),
                  Text(
                    rating.toStringAsFixed(1),
                    style: theme.textTheme.labelLarge,
                  ),
                  Text('·', style: muted),
                ],
                Text('฿' * place.priceLevel, style: theme.textTheme.labelLarge),
                Text('·', style: muted),
                Text(
                  stop.cost == 0
                      ? 'ไม่มีค่าใช้จ่าย'
                      : 'ประมาณ ${formatBaht(stop.cost)}',
                  style: muted,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(place.shortDescription, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            _InfoRow(
              icon: Icons.near_me_outlined,
              title: place.area ?? place.category.label,
              detail: stop.travelFromPrevMin > 0
                  ? 'ห่างจากจุดก่อนหน้า ${stop.travelFromPrevKm.toStringAsFixed(1)} กม. '
                        '· เดินทางราว ${formatMinutes(stop.travelFromPrevMin)}'
                  : null,
            ),
            _InfoRow(
              icon: Icons.schedule_outlined,
              title:
                  '${stop.start.toJson()} – ${stop.end.toJson()} '
                  '(${formatMinutes(stop.durationMin)})',
            ),
            _InfoRow(
              icon: Icons.storefront_outlined,
              title: 'เวลาเปิดทำการ',
              detail: !place.hasKnownOpeningHours
                  ? 'ไม่มีข้อมูลเวลาเปิด-ปิด'
                  : hours == null
                  ? 'ปิดวันนี้'
                  : 'เปิด ${hours.open.toJson()} – ${hours.close.toJson()}',
            ),
            if (stop.note != null) ...[
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: colors.tertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ทำไม AI เลือกที่นี่',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(stop.note!, style: muted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            for (final warning in stop.warnings) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 20,
                    color: colors.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      warning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showComingSoon(
                  context,
                  'สลับเป็นสถานที่ใกล้เคียง',
                  issue: 45,
                ),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('สลับเป็นสถานที่ใกล้เคียง'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, this.detail});

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Icon(icon, size: 18, color: colors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (detail != null)
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
