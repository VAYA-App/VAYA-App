import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers/data_providers.dart';

import '../../../domain/domain.dart';
import '../../../shared/formatters.dart';
import '../../../planner/geo.dart';
import '../../../planner/taste_profile.dart';
import 'stop_timeline.dart';

/// What the user chose in the sheet (#45).
sealed class StopAction {
  const StopAction();
}

final class SwapStop extends StopAction {
  const SwapStop(this.place);

  final Place place;
}

final class DeleteStop extends StopAction {
  const DeleteStop();
}

/// Opens the details of one Stop as a modal bottom sheet. With
/// [alternatives] it offers to swap the Stop for one of them, and
/// [canRemove] offers to take it out of the plan; the choice is returned.
Future<StopAction?> showStopDetailSheet(
  BuildContext context, {
  required int number,
  required Stop stop,
  required Place place,
  required DateTime date,
  List<Place> alternatives = const [],
  bool canRemove = false,
}) {
  return showModalBottomSheet<StopAction>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _StopDetail(
      number: number,
      stop: stop,
      place: place,
      date: date,
      alternatives: alternatives,
      canRemove: canRemove,
    ),
  );
}

class _StopDetail extends StatefulWidget {
  const _StopDetail({
    required this.number,
    required this.stop,
    required this.place,
    required this.date,
    required this.alternatives,
    required this.canRemove,
  });

  final int number;
  final Stop stop;
  final Place place;
  final DateTime date;
  final List<Place> alternatives;
  final bool canRemove;

  @override
  State<_StopDetail> createState() => _StopDetailState();
}

class _StopDetailState extends State<_StopDetail> {
  /// Showing the places to swap to instead of the swap button.
  var _choosing = false;

  int get number => widget.number;
  Stop get stop => widget.stop;
  Place get place => widget.place;
  DateTime get date => widget.date;

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
            const SizedBox(height: 16),
            _FeedbackRow(placeId: place.id),
            const SizedBox(height: 16),
            if (_choosing) ...[
              Text(
                'เลือกสถานที่แทน (ใกล้ที่สุดก่อน)',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final option in widget.alternatives)
                _AlternativeTile(
                  place: option,
                  km: haversineKm(place.location, option.location),
                  onTap: () => Navigator.of(context).pop(SwapStop(option)),
                ),
            ] else if (widget.alternatives.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _choosing = true),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('สลับเป็นสถานที่ใกล้เคียง'),
                ),
              ),
            if (widget.canRemove) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  onPressed: () =>
                      Navigator.of(context).pop(const DeleteStop()),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ลบจุดนี้ออกจากแผน'),
                ),
              ),
            ],
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

/// One place to swap to: name, kind, distance from the current Stop and
/// price level.
class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({
    required this.place,
    required this.km,
    required this.onTap,
  });

  final Place place;
  final double km;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(place.name),
        subtitle: Text(
          [
            'ห่าง ~${km.toStringAsFixed(1)} กม.',
            '฿' * place.priceLevel,
            if (place.rating case final rating?) '★ $rating',
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// 👍 / 👎 on the Place, which feeds the Taste Profile (#49). Tapping the
/// chosen one again clears it.
class _FeedbackRow extends ConsumerWidget {
  const _FeedbackRow({required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(
      tasteProfileProvider.select((t) => t.feedback[placeId]),
    );
    final taste = ref.read(tasteProfileProvider.notifier);

    Widget button(PlaceFeedback value, IconData off, IconData on, String tip) {
      final selected = current == value;
      return IconButton(
        isSelected: selected,
        tooltip: tip,
        icon: Icon(off),
        selectedIcon: Icon(on),
        onPressed: () => taste.set(placeId, selected ? null : value),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(switch (current) {
            PlaceFeedback.like => 'ชอบที่นี่ จะแนะนำที่แบบนี้มากขึ้น',
            PlaceFeedback.dislike => 'ไม่ชอบ จะไม่แนะนำที่นี่อีก',
            null => 'ชอบที่นี่ไหม?',
          }, style: theme.textTheme.bodyMedium),
        ),
        button(
          PlaceFeedback.like,
          Icons.thumb_up_outlined,
          Icons.thumb_up,
          'ชอบ',
        ),
        button(
          PlaceFeedback.dislike,
          Icons.thumb_down_outlined,
          Icons.thumb_down,
          'ไม่ชอบ',
        ),
      ],
    );
  }
}
