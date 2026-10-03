import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/mock_providers.dart';
import 'package:vaya_app/app/providers/planner_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';
import 'package:vaya_app/planner/mock_planner_service.dart';
import 'package:vaya_app/planner/planner_service.dart';

class _FailingPlanner implements PlannerService {
  @override
  Stream<PlanningProgress> generate({
    required TripRequest request,
    required String destinationId,
  }) => Stream.error(Exception('offline'));
}

void main() {
  Future<ProviderContainer> pumpGenerating(
    WidgetTester tester, {
    PlannerService? planner,
  }) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Asset loading needs real async; load what the screen reads first.
    final plan = await tester.runAsync(
      () => ProviderContainer().read(mockTripPlanProvider.future),
    );
    final container = ProviderContainer(
      overrides: [
        plannerServiceProvider.overrideWithValue(
          planner ??
              MockPlannerService(
                loadPlan: () async => plan!,
                stepDelay: const Duration(milliseconds: 100),
              ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(mockTripRequestProvider.future);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    container
        .read(routerProvider)
        .go('${AppRoutes.generating}?destination=chonburi');
    await tester.pump();
    // Let the page transition finish without waiting for the spinner.
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  testWidgets('shows progress and opens the plan as a draft when done', (
    tester,
  ) async {
    final container = await pumpGenerating(tester);

    expect(find.text('กำลังจัดทริปที่ใช่ให้คุณ'), findsOneWidget);
    expect(find.textContaining('ชลบุรี'), findsOneWidget);
    expect(find.text('เกร็ดน่ารู้ระหว่างรอ'), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final location = container
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    expect(location, AppRoutes.tripPlan('draft-1'));
    final draft = container.read(draftTripsProvider)['draft-1'];
    expect(draft?.plan.destinationId, 'chonburi');
  });

  testWidgets('offers a retry when planning fails', (tester) async {
    await pumpGenerating(tester, planner: _FailingPlanner());
    await tester.pumpAndSettle();

    expect(find.text('สร้างแผนไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);

    await tester.tap(find.text('กลับไปแก้คำขอ'));
    await tester.pumpAndSettle();
    expect(find.text('ขั้นที่ 1 จาก 4'), findsOneWidget);
  });
}
