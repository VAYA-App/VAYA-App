import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/features/trip_plan/trip_calendar_export.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_screen.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TripPlanView view;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    view = (await container.read(tripPlanViewProvider(mockTripId).future))!;
  });

  /// Unfolds continuation lines, as calendar apps do.
  List<String> unfold(String ics) =>
      ics.replaceAll('\r\n ', '').split('\r\n')..removeLast();

  test('one event per stop, in UTC from Thai time', () {
    final ics = tripCalendarIcs(view, now: DateTime.utc(2026, 10, 23, 8));
    final lines = unfold(ics);
    final stops = view.plan.days.expand((d) => d.stops).toList();

    expect(lines.first, 'BEGIN:VCALENDAR');
    expect(lines.last, 'END:VCALENDAR');
    expect(lines.where((l) => l == 'BEGIN:VEVENT'), hasLength(stops.length));
    expect(lines, contains('DTSTAMP:20261023T080000Z'));

    final first = stops.first;
    final start = first.start;
    // 14 Nov in Thailand is 7 hours ahead of UTC.
    final utcHour = (start.hour - 7).toString().padLeft(2, '0');
    final minute = start.minute.toString().padLeft(2, '0');
    expect(lines, contains('DTSTART:20261114T$utcHour${minute}00Z'));
    expect(
      lines,
      contains('SUMMARY:${view.catalog.place(first.placeId).name}'),
    );
    expect(lines.where((l) => l.startsWith('GEO:')), hasLength(stops.length));
    // UIDs are unique so a second import updates rather than duplicates.
    final uids = lines.where((l) => l.startsWith('UID:')).toList();
    expect(uids.toSet(), hasLength(uids.length));
  });

  test('lines are folded at 75 octets without breaking characters', () {
    final ics = tripCalendarIcs(view);
    for (final line in ics.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
    }
    // Folding round-trips.
    expect(
      unfold(ics).where((l) => l.startsWith('X-WR-CALNAME:')).single,
      'X-WR-CALNAME:ทริปชลบุรี',
    );
  });

  testWidgets('the share menu sends the calendar file', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
    final shared = <String>[];
    final container = ProviderContainer(
      overrides: [
        shareCalendarProvider.overrideWithValue((ics, {origin}) async {
          shared.add(ics);
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(tripPlanViewProvider(mockTripId).future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TripPlanScreen(tripId: mockTripId)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('แชร์แผน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มลงปฏิทิน'));
    await tester.pump();

    expect(shared, hasLength(1));
    expect(shared.single, startsWith('BEGIN:VCALENDAR'));
  });
}
