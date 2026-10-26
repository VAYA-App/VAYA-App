import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/mock_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_screen.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';

void main() {
  late ProviderContainer container;

  String location() => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  Future<void> openMockPlan(WidgetTester tester) async {
    // Two-pane layout; the map's attribution overflows a phone in tests.
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
    // The map's tile cache asks for a directory once real time passes.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(mockTripPlanProvider.future);
      await container.read(mockTripRequestProvider.future);
      await container.read(tripPlanViewProvider(mockTripId).future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    container.read(routerProvider).go(AppRoutes.tripPlan(mockTripId));
    await tester.pumpAndSettle();
  }

  /// Opening a trip by id resolves outside the fake clock; give it real
  /// time before settling.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('บันทึกทริป'));
    await settle(tester);
  }

  testWidgets('saving reopens the plan as a saved trip', (tester) async {
    await openMockPlan(tester);
    expect(find.byTooltip('ตัวเลือกเพิ่มเติม'), findsNothing);

    await save(tester);

    expect(find.text('บันทึกแล้ว'), findsWidgets); // button and SnackBar
    expect(location(), AppRoutes.tripPlan('trip-1'));
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.byIcon(Icons.bookmark_added),
              matching: find.bySubtype<OutlinedButton>(),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.byTooltip('ตัวเลือกเพิ่มเติม'), findsOneWidget);

    final trips = await container
        .read(tripRepositoryProvider)
        .watchMyTrips()
        .first;
    expect(trips, hasLength(1));
    expect(trips.single.ownerUid, MockAuthRepository.demoUser.uid);
    expect(trips.single.plan.destinationId, 'chonburi');
  });

  testWidgets('a saved trip opens from my trips with the same plan', (
    tester,
  ) async {
    await openMockPlan(tester);
    await save(tester);

    // Let the "บันทึกแล้ว" SnackBar go before checking the saved state.
    await tester.pump(const Duration(seconds: 5));
    container.read(routerProvider).go(AppRoutes.myTrips);
    await tester.pumpAndSettle();
    final card = find.text('ชลบุรี 2 วัน 1 คืน');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await settle(tester);

    expect(find.byType(TripPlanScreen), findsOneWidget);
    expect(find.textContaining('ชลบุรี 2 วัน 1 คืน'), findsOneWidget);
    expect(find.text('บันทึกแล้ว'), findsOneWidget);
  });

  testWidgets('deleting asks first, then goes home without the trip', (
    tester,
  ) async {
    await openMockPlan(tester);
    await save(tester);

    Future<void> openDelete() async {
      await tester.tap(find.byTooltip('ตัวเลือกเพิ่มเติม'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบทริป'));
      await tester.pumpAndSettle();
    }

    await openDelete();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(location(), AppRoutes.tripPlan('trip-1'));

    await openDelete();
    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(location(), AppRoutes.home);
    expect(find.text('ลบทริปแล้ว'), findsOneWidget);
    expect(
      await container.read(tripRepositoryProvider).getTrip('trip-1'),
      isNull,
    );
  });
}
