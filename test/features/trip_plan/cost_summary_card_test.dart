import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/mock_providers.dart';
import 'package:vaya_app/app/theme/app_theme.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_screen.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';
import 'package:vaya_app/features/trip_plan/widgets/cost_summary_card.dart';

/// The Cost Estimate of the bundled mock plan: ฿6,582 of ฿7,000 for two.
CostEstimate _mockCost() => TripPlan.fromJson(
  jsonDecode(File('assets/mock/trip_plan_chonburi_2d.json').readAsStringSync())
      as Map<String, Object?>,
).cost;

CostEstimate _withBudget(CostEstimate cost, int budget) => CostEstimate(
  intercity: cost.intercity,
  accommodation: cost.accommodation,
  food: cost.food,
  entrance: cost.entrance,
  localTransport: cost.localTransport,
  buffer: cost.buffer,
  total: cost.total,
  perPerson: cost.perPerson,
  budget: budget,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    CostEstimate cost, {
    bool dark = false,
    double textScale = 1,
    Size size = const Size(412, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CostSummaryCard(cost: cost, travellerCount: 2),
          ),
        ),
      ),
    );
  }

  double barValue(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .value!;

  testWidgets('shows the total, the budget and the share per person', (
    tester,
  ) async {
    await pumpCard(tester, _mockCost());

    // The big number is what the trip costs, not the budget (#102).
    expect(find.text('ค่าใช้จ่ายรวมทั้งทริป'), findsOneWidget);
    expect(find.textContaining('฿6,582'), findsOneWidget);
    expect(find.textContaining('งบ ฿7,000'), findsOneWidget);
    expect(find.textContaining('฿3,291'), findsOneWidget);
    expect(find.textContaining('(2 ท่าน)'), findsOneWidget);
    expect(find.text('ราคาโดยประมาณ'), findsOneWidget);
  });

  testWidgets('fills the bar by the share of the budget spent', (tester) async {
    await pumpCard(tester, _mockCost());

    expect(barValue(tester), closeTo(6582 / 7000, 0.0001));
    expect(find.text('94% ของงบ'), findsOneWidget);
  });

  testWidgets('over budget: a full bar and the real percentage', (
    tester,
  ) async {
    await pumpCard(tester, _withBudget(_mockCost(), 6000));

    expect(barValue(tester), 1);
    expect(find.text('110% ของงบ'), findsOneWidget);
  });

  testWidgets('without a budget there is no bar', (tester) async {
    await pumpCard(tester, _withBudget(_mockCost(), 0));

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('฿6,582'), findsOneWidget);
  });

  testWidgets('tapping lists every category, the buffer and the total', (
    tester,
  ) async {
    await pumpCard(tester, _mockCost());
    await tester.tap(find.text('ดูรายละเอียด'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    Finder row(String label, String amount) => find.descendant(
      of: sheet,
      matching: find.ancestor(
        of: find.text(amount),
        matching: find.widgetWithText(ListTile, label),
      ),
    );

    expect(row('เดินทางข้ามเมือง', '฿524'), findsOneWidget);
    expect(row('ที่พัก', '฿3,000'), findsOneWidget);
    expect(row('อาหาร', '฿920'), findsOneWidget);
    expect(row('ค่าเข้าชม', '฿1,000'), findsOneWidget);
    expect(row('เดินทางในพื้นที่', '฿540'), findsOneWidget);
    expect(row('ค่าใช้จ่ายจริง', '฿5,984'), findsOneWidget);
    expect(row('เงินสำรอง', '฿598'), findsOneWidget);
    expect(row('รวมทั้งหมด', '฿6,582'), findsOneWidget);
    expect(row('งบที่ตั้งไว้', '฿7,000'), findsOneWidget);
    expect(row('เฉลี่ยต่อคน (2 ท่าน)', '฿3,291'), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.textContaining('โดยประมาณ')),
      findsOneWidget,
    );
  });

  testWidgets('a category that costs nothing is still listed', (tester) async {
    const cost = CostEstimate(
      intercity: 0,
      accommodation: 0,
      food: 500,
      entrance: 0,
      localTransport: 120,
      buffer: 62,
      total: 682,
      perPerson: 341,
      budget: 1000,
    );
    await pumpCard(tester, cost);
    await tester.tap(find.text('ดูรายละเอียด'));
    await tester.pumpAndSettle();

    for (final label in ['เดินทางข้ามเมือง', 'ที่พัก', 'ค่าเข้าชม']) {
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, label),
          matching: find.text('฿0'),
        ),
        findsOneWidget,
        reason: label,
      );
    }
  });

  for (final dark in [false, true]) {
    testWidgets(
      'fits a narrow phone at 200% text (${dark ? 'dark' : 'light'})',
      (tester) async {
        await pumpCard(
          tester,
          _withBudget(_mockCost(), 6000),
          dark: dark,
          textScale: 2,
          size: const Size(360, 800),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('ดูรายละเอียด'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('รวมทั้งหมด'), findsOneWidget);
      },
    );
  }

  testWidgets('the trip plan screen shows the card and opens the sheet', (
    tester,
  ) async {
    // Wide enough for the two-pane layout; the map's attribution row
    // overflows a phone-sized map in the test font.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: MockAuthRepository.demoUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Asset loading needs real async; load what the screen reads first.
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(mockTripPlanProvider.future);
      await container.read(mockTripRequestProvider.future);
      await container.read(tripPlanViewProvider(mockTripId).future);
    });

    // The screen on its own, not through the app's router, so this does
    // not depend on being signed in (#15).
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TripPlanScreen(tripId: mockTripId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CostSummaryCard), findsOneWidget);
    expect(find.textContaining('฿6,582'), findsOneWidget);

    await tester.tap(find.text('ดูรายละเอียด'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('รายละเอียดค่าใช้จ่าย'), findsOneWidget);
    expect(find.text('เดินทางข้ามเมือง'), findsOneWidget);
  });
}
