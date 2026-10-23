import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'trip_plan_view_provider.dart';

/// Every Stop as an event in an iCalendar file (RFC 5545), which the
/// calendar apps on Android and iOS add from the share sheet (#47).
/// Times are Thailand time (UTC+7, no daylight saving), written in UTC.
String tripCalendarIcs(TripPlanView view, {DateTime? now}) {
  String utc(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}'
        'T${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  }

  /// [minutes] after midnight on [date] in Thailand, as UTC.
  String thai(DateTime date, int minutes) => utc(
    DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: minutes - 7 * 60)),
  );

  final stamp = utc((now ?? DateTime.now()).toUtc());
  final key =
      view.savedTrip?.id ??
      '${view.plan.destinationId}-${view.request.startDate.millisecondsSinceEpoch}';
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//VAYA//Trip Planner//TH',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:ทริป${_text(view.destination.name)}',
    for (final (d, day) in view.plan.days.indexed)
      for (final (i, stop) in day.stops.indexed) ...[
        'BEGIN:VEVENT',
        'UID:$key-${d + 1}-${i + 1}@vaya.app',
        'DTSTAMP:$stamp',
        'DTSTART:${thai(day.date, stop.start.minutesSinceMidnight)}',
        'DTEND:${thai(day.date, stop.end.minutesSinceMidnight)}',
        'SUMMARY:${_text(view.catalog.place(stop.placeId).name)}',
        'LOCATION:${_text(view.catalog.place(stop.placeId).name)}',
        'GEO:${view.catalog.place(stop.placeId).location.lat};'
            '${view.catalog.place(stop.placeId).location.lng}',
        if (stop.note case final note?) 'DESCRIPTION:${_text(note)}',
        'END:VEVENT',
      ],
    'END:VCALENDAR',
  ];
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

/// Escapes a TEXT value (RFC 5545 §3.3.11).
String _text(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\n', r'\n');

/// Folds a line to at most 75 octets, never splitting a character
/// (RFC 5545 §3.1).
String _fold(String line) {
  final parts = <String>[];
  var current = StringBuffer();
  var octets = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final size = utf8.encode(char).length;
    // Continuation lines start with a space, which counts.
    final limit = parts.isEmpty ? 75 : 74;
    if (octets + size > limit) {
      parts.add(current.toString());
      current = StringBuffer();
      octets = 0;
    }
    current.write(char);
    octets += size;
  }
  parts.add(current.toString());
  return parts.join('\r\n ');
}

/// Shares the calendar file; tests override it. [origin] anchors the
/// popover on iPad.
final shareCalendarProvider =
    Provider<Future<void> Function(String ics, {Rect? origin})>(
      (ref) =>
          (ics, {origin}) => SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(
                  Uint8List.fromList(utf8.encode(ics)),
                  mimeType: 'text/calendar',
                  name: 'vaya-trip.ics',
                ),
              ],
              fileNameOverrides: ['vaya-trip.ics'],
              sharePositionOrigin: origin,
            ),
          ),
    );
