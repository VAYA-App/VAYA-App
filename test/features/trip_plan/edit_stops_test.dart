import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/planner_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';

void main() {
  late ProviderContainer container;

  String location() => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  /// The edit and the reopened plan resolve outside the fake clock; give
  /// them real time in a few rounds before settling.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> openMockPlan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: MockAuthRepository.demoUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(planEditorProvider.future);
      await container.read(tripPlanViewProvider(mockTripId).future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    container.read(routerProvider).go(AppRoutes.tripPlan(mockTripId));
    await tester.pumpAndSettle();
  }

  Future<void> openStop(WidgetTester tester, String name) async {
    final stop = find.text(name).first;
    await tester.ensureVisible(stop);
    await tester.pumpAndSettle();
    await tester.tap(stop);
    await tester.pumpAndSettle();
  }

  testWidgets('swapping a stop makes the mock a draft with the new place', (
    tester,
  ) async {
    await openMockPlan(tester);
    await openStop(tester, 'ปราสาทสัจธรรม');

    await tester.tap(find.text('สลับเป็นสถานที่ใกล้เคียง'));
    await tester.pumpAndSettle();
    final options = find.textContaining('ห่าง ~');
    expect(options, findsNWidgets(5));
    final first = tester
        .widget<Text>(
          find
              .descendant(
                of: find.ancestor(
                  of: options.first,
                  matching: find.byType(ListTile),
                ),
                matching: find.byType(Text),
              )
              .first,
        )
        .data!;

    await tester.tap(options.first);
    await settle(tester);

    expect(location(), AppRoutes.tripPlan('draft-1'));
    expect(
      find.textContaining('เปลี่ยนปราสาทสัจธรรมเป็น$first'),
      findsOneWidget,
    );
    final plan = container.read(draftTripsProvider)['draft-1']!.plan;
    expect(
      plan.days.first.stops.map((s) => s.placeId),
      isNot(contains('chonburi-attraction-sanctuary-of-truth')),
    );
  });

  testWidgets('removing a stop can be undone', (tester) async {
    await openMockPlan(tester);
    await openStop(tester, 'ปราสาทสัจธรรม');

    await tester.tap(find.text('ลบจุดนี้ออกจากแผน'));
    await settle(tester);

    expect(find.text('ลบปราสาทสัจธรรมออกจากแผนแล้ว'), findsOneWidget);
    int stops() => container
        .read(draftTripsProvider)['draft-1']!
        .plan
        .days
        .first
        .stops
        .length;
    expect(stops(), 3);

    await tester.tap(find.text('เลิกทำ'));
    await settle(tester);
    expect(stops(), 4);
  });
}
