import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_screen.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';
import 'package:vaya_app/features/trip_plan/trip_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the summary has the trip, the money and every stop', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final view = (await container.read(
      tripPlanViewProvider(mockTripId).future,
    ))!;

    final text = tripSummaryText(view);
    final lines = text.split('\n');

    expect(lines.first, 'ทริปชลบุรี 2 วัน 1 คืน (14–15 พ.ย.) · 2 คน');
    expect(lines[1], 'ค่าใช้จ่ายโดยประมาณ ฿6,582 (คนละ ฿3,291) · งบ ฿7,000');
    expect(text, contains('เดินทาง: รถทัวร์/รถตู้ ไป–กลับ'));
    expect(text, contains('ที่พัก: Hard Rock Hotel Pattaya'));
    expect(text, contains('วันที่ 1 · ส. 14 พ.ย.'));
    expect(text, contains('วันที่ 2 · อา. 15 พ.ย.'));
    for (final stop in view.plan.days.expand((d) => d.stops)) {
      expect(
        text,
        contains('${stop.start} ${view.catalog.place(stop.placeId).name}'),
      );
    }
    expect(lines.last, 'วางแผนด้วย VAYA');
  });

  testWidgets('the share button sends the summary', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );

    final shared = <(String, Rect?)>[];
    final container = ProviderContainer(
      overrides: [
        shareTextProvider.overrideWithValue((text, {origin}) async {
          shared.add((text, origin));
        }),
      ],
    );
    addTearDown(container.dispose);
    late TripPlanView view;
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      view = (await container.read(tripPlanViewProvider(mockTripId).future))!;
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TripPlanScreen(tripId: mockTripId)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('แชร์แผน'));
    await tester.pump();

    expect(shared, hasLength(1));
    expect(shared.single.$1, tripSummaryText(view));
    expect(shared.single.$2, isNotNull);
  });
}
