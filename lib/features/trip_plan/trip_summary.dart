import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/formatters.dart';
import 'trip_plan_view_provider.dart';

/// The plan as plain text to send to friends (#48).
String tripSummaryText(TripPlanView view) {
  final plan = view.plan;
  final request = view.request;
  final days = plan.days.length;
  final cost = plan.cost;
  final stays = {
    for (final stay in plan.nightStays) view.catalog.place(stay.placeId).name,
  };
  return [
    'ทริป${view.destination.name} '
        '${days == 1 ? '1 วัน' : '$days วัน ${days - 1} คืน'} '
        '(${formatDateRange(request.startDate, request.endDate)}) '
        '· ${request.travellerCount} คน',
    'ค่าใช้จ่ายโดยประมาณ ${formatBaht(cost.total)} '
        '(คนละ ${formatBaht(cost.perPerson)}) · งบ ${formatBaht(cost.budget)}',
    if (plan.intercity case final leg?) 'เดินทาง: ${leg.mode.label} ไป–กลับ',
    if (stays.isNotEmpty) 'ที่พัก: ${stays.join(', ')}',
    for (final (i, day) in plan.days.indexed) ...[
      '',
      'วันที่ ${i + 1} · ${formatThaiShortDate(day.date)}',
      for (final stop in day.stops)
        '${stop.start} ${view.catalog.place(stop.placeId).name}',
    ],
    '',
    'วางแผนด้วย VAYA',
  ].join('\n');
}

/// Opens the system share sheet; tests override it. [origin] anchors the
/// popover on iPad.
final shareTextProvider =
    Provider<Future<void> Function(String text, {Rect? origin})>(
      (ref) =>
          (text, {origin}) => SharePlus.instance.share(
            ShareParams(text: text, sharePositionOrigin: origin),
          ),
    );
