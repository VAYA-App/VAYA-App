import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/mock_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/data/mock/in_memory_trip_repository.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_screen.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpCalendar(
    WidgetTester tester, {
    required List<(String id, DateTime start, DateTime end)> trips,
    double textScale = 1,
    Size size = const Size(412, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = InMemoryTripRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: MockAuthRepository.demoUser),
        ),
        tripRepositoryProvider.overrideWithValue(repo),
        todayProvider.overrideWithValue(DateTime(2026, 10, 23)),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      final plan = await container.read(mockTripPlanProvider.future);
      final request = await container.read(mockTripRequestProvider.future);
      for (final (id, start, end) in trips) {
        await repo.saveTrip(
          Trip(
            id: id,
            ownerUid: MockAuthRepository.demoUser.uid,
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
            request: request.copyWith(startDate: start, endDate: end),
            plan: plan,
          ),
        );
      }
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    container.read(routerProvider).go(AppRoutes.myTrips);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ปฏิทิน'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the next trip and marks its days', (tester) async {
    await pumpCalendar(
      tester,
      trips: [
        ('past', DateTime(2026, 9, 5), DateTime(2026, 9, 6)),
        ('next', DateTime(2026, 11, 14), DateTime(2026, 11, 15)),
      ],
    );

    expect(find.text('พฤศจิกายน 2569'), findsOneWidget);
    expect(find.bySemanticsLabel('วันที่ 14 ทริปชลบุรี'), findsOneWidget);
    expect(find.bySemanticsLabel('วันที่ 15 ทริปชลบุรี'), findsOneWidget);
    expect(find.bySemanticsLabel('วันที่ 16'), findsOneWidget);
    expect(find.text('14–15 พ.ย. · 2 คน'), findsOneWidget);
  });

  testWidgets('moves between months', (tester) async {
    await pumpCalendar(
      tester,
      trips: [('past', DateTime(2026, 9, 5), DateTime(2026, 9, 6))],
    );
    // No trip ahead: this month, with today marked.
    expect(find.text('ตุลาคม 2569'), findsOneWidget);
    expect(find.bySemanticsLabel('วันที่ 23 วันนี้'), findsOneWidget);
    expect(find.text('ไม่มีทริปในเดือนนี้'), findsOneWidget);

    await tester.tap(find.byTooltip('เดือนก่อน'));
    await tester.pumpAndSettle();
    expect(find.text('กันยายน 2569'), findsOneWidget);
    expect(find.text('5–6 ก.ย. · 2 คน'), findsOneWidget);

    await tester.tap(find.byTooltip('เดือนถัดไป'));
    await tester.tap(find.byTooltip('เดือนถัดไป'));
    await tester.tap(find.byTooltip('เดือนถัดไป'));
    await tester.tap(find.byTooltip('เดือนถัดไป'));
    await tester.pumpAndSettle();
    expect(find.text('มกราคม 2570'), findsOneWidget);
  });

  testWidgets('a trip day opens the trip', (tester) async {
    await pumpCalendar(
      tester,
      trips: [('next', DateTime(2026, 11, 14), DateTime(2026, 11, 15))],
    );

    await tester.tap(find.bySemanticsLabel('วันที่ 14 ทริปชลบุรี'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TripPlanScreen), findsOneWidget);
  });

  testWidgets('fits 200% text on a narrow phone', (tester) async {
    await pumpCalendar(
      tester,
      trips: [('next', DateTime(2026, 11, 14), DateTime(2026, 11, 15))],
      textScale: 2,
      size: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
  });
}
