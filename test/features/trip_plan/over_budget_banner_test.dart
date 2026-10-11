import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/mock_providers.dart';
import 'package:vaya_app/app/providers/planner_providers.dart';
import 'package:vaya_app/app/theme/app_theme.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_screen.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';
import 'package:vaya_app/features/trip_plan/widgets/budget_advice_list.dart';
import 'package:vaya_app/features/trip_plan/widgets/over_budget_banner.dart';
import 'package:vaya_app/planner/default_over_budget_advisor.dart';
import 'package:vaya_app/shared/formatters.dart';
import 'package:vaya_app/shared/widgets/mascot_view.dart';

/// The mock plan's cost (real cost 5,984 + buffer 598 = 6,582) against
/// another [budget].
CostEstimate _cost(int budget) => CostEstimate(
  intercity: 524,
  accommodation: 3000,
  food: 920,
  entrance: 1000,
  localTransport: 540,
  buffer: 598,
  total: 6582,
  perPerson: 3291,
  budget: budget,
);

const _advice = [
  BudgetAdvice(
    kind: BudgetAdviceKind.removeDay,
    saving: 5223,
    description: 'ลดเหลือ 1 วัน ไม่ค้างคืน ประหยัด ~฿5,223',
  ),
  BudgetAdvice(
    kind: BudgetAdviceKind.downgradeAccommodation,
    saving: 1650,
    description: 'เปลี่ยนที่พักเป็น บ้านพักริมหาด (฿฿) ประหยัด ~฿1,650',
  ),
  BudgetAdvice(
    kind: BudgetAdviceKind.changeLocalTransport,
    saving: 2400,
    description: 'เปลี่ยนเป็นรถสาธารณะ ประหยัด ~฿2,400',
  ),
  BudgetAdvice(
    kind: BudgetAdviceKind.changeDestination,
    saving: 400,
    description: 'เที่ยวกรุงเทพมหานครแทน เริ่มต้นถูกกว่า ~฿400',
  ),
];

/// Without the province estimate, which the rescue never applies.
final _pricedAdvice = _advice.sublist(0, 3);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
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
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('OverBudgetBanner', () {
    testWidgets('says how far over, with a warning icon', (tester) async {
      await pump(tester, OverBudgetBanner(cost: _cost(5000)));

      expect(find.text('เกินงบ ฿1,582'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      expect(find.textContaining('ดูวิธีลดค่าใช้จ่ายด้านล่าง'), findsOneWidget);
    });

    testWidgets('does not point at advice that is not there', (tester) async {
      await pump(tester, OverBudgetBanner(cost: _cost(5000), hasAdvice: false));

      expect(find.textContaining('ด้านล่าง'), findsNothing);
      expect(find.textContaining('ลองเพิ่มงบหรือลดจำนวนวัน'), findsOneWidget);
    });

    testWidgets('a day trip is not told to drop a day', (tester) async {
      await pump(
        tester,
        OverBudgetBanner(
          cost: _cost(5000),
          hasAdvice: false,
          canShorten: false,
        ),
      );

      expect(find.textContaining('ลดจำนวนวัน'), findsNothing);
      expect(find.textContaining('ลองเพิ่มงบดู'), findsOneWidget);
    });

    testWidgets('is softer when only the buffer goes over', (tester) async {
      await pump(tester, OverBudgetBanner(cost: _cost(6200)));

      expect(find.text('เกินงบ ฿382 เพราะเงินสำรอง'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsNothing);
      expect(find.textContaining('ค่าใช้จ่ายจริง ฿5,984'), findsOneWidget);
      expect(find.textContaining('เงินสำรอง ฿598'), findsOneWidget);
    });

    testWidgets('the real cost equal to the budget still counts as soft', (
      tester,
    ) async {
      await pump(tester, OverBudgetBanner(cost: _cost(5984)));
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await pump(tester, OverBudgetBanner(cost: _cost(5983)));
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      expect(find.text('เกินงบ ฿599'), findsOneWidget);
    });

    testWidgets('screen readers hear the amount, not the mascot', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, OverBudgetBanner(cost: _cost(5000)));

      expect(find.bySemanticsLabel(RegExp('เกินงบ ฿1,582')), findsOneWidget);
      expect(find.byType(MascotView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MascotView),
          matching: find.bySemanticsLabel(RegExp('.')),
        ),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('large text takes the mascot away', (tester) async {
      await pump(tester, OverBudgetBanner(cost: _cost(5000)), textScale: 2);

      expect(find.byType(MascotView), findsNothing);
      expect(find.text('เกินงบ ฿1,582'), findsOneWidget);
    });
  });

  group('BudgetAdviceList', () {
    testWidgets('shows every option with its own icon', (tester) async {
      await pump(tester, const BudgetAdviceList(advice: _advice));

      for (final item in _advice) {
        expect(find.text(item.description), findsOneWidget);
      }
      for (final icon in [
        Icons.event_busy_outlined,
        Icons.bed_outlined,
        Icons.commute_outlined,
        Icons.map_outlined,
      ]) {
        expect(find.byIcon(icon), findsOneWidget);
      }
      expect(find.textContaining('นำมารวมกันไม่ได้'), findsOneWidget);
      expect(find.textContaining('ราคาโดยประมาณ'), findsOneWidget);
    });
  });

  group('BudgetRescueCard', () {
    testWidgets('names the budget needed and a trip length that fits', (
      tester,
    ) async {
      await pump(
        tester,
        BudgetRescueCard(
          advice: _pricedAdvice,
          dayCount: 3,
          budget: 3000,
          rescue: const BudgetRescue(
            stillOverBy: 7789,
            minimumBudget: 6100,
            daysThatFit: 1,
            costOfDaysThatFit: 1197,
          ),
        ),
      );

      // What is left of this plan leads; the cheapest trip comes second.
      final title = find.text('ทำทุกวิธีข้างบนพร้อมกันแล้วยังเกินงบอีก ฿7,789');
      final minimum = find.text('ควรมีงบอย่างน้อย ฿6,100 สำหรับทริป 3 วัน');
      expect(title, findsOneWidget);
      expect(minimum, findsOneWidget);
      expect(
        tester.getTopLeft(title).dy,
        lessThan(tester.getTopLeft(minimum).dy),
      );
      expect(
        find.text('หรือลดเหลือ 1 วันแบบประหยัดสุด เริ่มต้น ~฿1,197'),
        findsOneWidget,
      );
      // The minimum is another, cheaper trip, not this plan.
      expect(find.textContaining('แผนจริงอาจสูงกว่านี้'), findsOneWidget);
    });

    testWidgets('says so when not even a day trip fits', (tester) async {
      const rescue = BudgetRescue(stillOverBy: 900, minimumBudget: 1200);

      await pump(
        tester,
        BudgetRescueCard(
          advice: _pricedAdvice,
          dayCount: 2,
          budget: 500,
          rescue: rescue,
        ),
      );
      expect(find.text('งบนี้ยังไม่พอแม้เป็นทริป 1 วัน'), findsOneWidget);

      // Already a day trip: nothing shorter to mention.
      await pump(
        tester,
        BudgetRescueCard(
          advice: _pricedAdvice,
          dayCount: 1,
          budget: 500,
          rescue: rescue,
        ),
      );
      expect(find.textContaining('แม้เป็นทริป 1 วัน'), findsNothing);
    });

    testWidgets('never asks for a budget the user already has', (tester) async {
      // The cheapest trip (2,000) fits ฿2,500, yet this plan with every
      // option applied is still 342 over.
      await pump(
        tester,
        BudgetRescueCard(
          advice: _pricedAdvice,
          dayCount: 2,
          budget: 2500,
          rescue: const BudgetRescue(
            stillOverBy: 342,
            minimumBudget: 2000,
            daysThatFit: 1,
            costOfDaysThatFit: 664,
          ),
        ),
      );

      expect(find.textContaining('ควรมีงบอย่างน้อย'), findsNothing);
      expect(find.textContaining('฿2,000'), findsNothing);
      expect(
        find.text('ทำทุกวิธีข้างบนพร้อมกันแล้วยังเกินงบอีก ฿342'),
        findsOneWidget,
      );
      expect(find.textContaining('ลองเพิ่มงบอีกราว ฿342'), findsOneWidget);
    });

    testWidgets('does not claim to have tried another province', (
      tester,
    ) async {
      await pump(
        tester,
        const BudgetRescueCard(
          advice: _advice,
          dayCount: 2,
          budget: 2500,
          rescue: BudgetRescue(stillOverBy: 342, minimumBudget: 2000),
        ),
      );

      expect(
        find.text(
          'ทำทุกวิธีข้างบนพร้อมกัน ยกเว้นเปลี่ยนจังหวัด ยังเกินงบอีก ฿342',
        ),
        findsOneWidget,
      );
    });

    testWidgets('leaves the amount to the banner when no option is priced', (
      tester,
    ) async {
      // Nothing was applied, so what is left is what the banner said.
      const rescue = BudgetRescue(stillOverBy: 342, minimumBudget: 2000);
      const title = 'ระบบยังหาวิธีลดค่าใช้จ่ายของแผนนี้ให้ไม่ได้';

      await pump(
        tester,
        const BudgetRescueCard(
          advice: [],
          dayCount: 1,
          budget: 2500,
          rescue: rescue,
        ),
      );
      expect(find.text(title), findsOneWidget);
      expect(find.textContaining('ข้างบน'), findsNothing);
      expect(find.textContaining('฿'), findsNothing);
      // Cheaper places can still be picked by hand; a day trip has no hotel.
      expect(find.textContaining('ลดค่าใช้จ่ายต่อไม่ได้'), findsNothing);
      expect(find.textContaining('ที่พัก'), findsNothing);
      expect(
        find.text('ลองเพิ่มงบ หรือเลือกร้านอาหารและที่เที่ยวที่ราคาต่ำลง'),
        findsOneWidget,
      );

      // Another province is listed, but it is not this plan made cheaper.
      await pump(
        tester,
        BudgetRescueCard(
          advice: [_advice.last],
          dayCount: 1,
          budget: 2500,
          rescue: rescue,
        ),
      );
      expect(find.text(title), findsOneWidget);
      expect(find.textContaining('฿'), findsNothing);
    });

    testWidgets('still names the budget needed when no option is priced', (
      tester,
    ) async {
      await pump(
        tester,
        const BudgetRescueCard(
          advice: [],
          dayCount: 1,
          budget: 1500,
          rescue: BudgetRescue(stillOverBy: 342, minimumBudget: 2000),
        ),
      );

      expect(find.textContaining('฿342'), findsNothing);
      expect(
        find.text('ควรมีงบอย่างน้อย ฿2,000 สำหรับทริป 1 วัน'),
        findsOneWidget,
      );
    });
  });

  for (final dark in [false, true]) {
    testWidgets('everything fits a narrow phone at 200% text '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            OverBudgetBanner(cost: _cost(5000)),
            OverBudgetBanner(cost: _cost(6200)),
            const BudgetAdviceList(advice: _advice),
            const BudgetRescueCard(
              advice: _advice,
              dayCount: 3,
              budget: 3000,
              rescue: BudgetRescue(
                stillOverBy: 7789,
                minimumBudget: 6100,
                daysThatFit: 1,
                costOfDaysThatFit: 1197,
              ),
            ),
          ],
        ),
        dark: dark,
        textScale: 2,
        size: const Size(360, 800),
      );

      expect(tester.takeException(), isNull);
    });
  }

  group('on the trip plan screen', () {
    /// The over-budget amount wherever it is written, and not as the start
    /// of a longer number.
    RegExp amountOf(CostEstimate cost) =>
        RegExp('${RegExp.escape(formatBaht(cost.overBy))}(?![\\d,])');

    Future<ProviderContainer> open(
      WidgetTester tester,
      String tripId, {
      ProviderContainer? within,
    }) async {
      // Wide enough for the two-pane layout; the map's attribution row
      // overflows a phone-sized map in the test font.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = within ?? ProviderContainer();
      if (within == null) addTearDown(container.dispose);
      // Asset loading needs real async; load what the screen reads first.
      await tester.runAsync(() async {
        await container.read(tripPlanViewProvider(tripId).future);
        await container.read(budgetRescueProvider(tripId).future);
      });

      // The screen on its own, not through the app's router, so this does
      // not depend on being signed in.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: TripPlanScreen(tripId: tripId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return container;
    }

    testWidgets('an over-budget plan gets the banner, advice and rescue', (
      tester,
    ) async {
      final container = await open(tester, mockOverBudgetTripId);
      final view = container
          .read(tripPlanViewProvider(mockOverBudgetTripId))
          .value!;

      expect(view.plan.status, PlanStatus.overBudget);
      expect(view.plan.overBudgetAdvice, isNotEmpty);
      expect(find.byType(OverBudgetBanner), findsOneWidget);
      expect(find.byType(BudgetAdviceList), findsOneWidget);
      for (final item in view.plan.overBudgetAdvice) {
        expect(find.text(item.description), findsOneWidget);
      }
      expect(find.byType(BudgetRescueCard), findsOneWidget);
      // One mascot per screen (docs/MASCOT.md).
      expect(find.byType(MascotView), findsOneWidget);
    });

    testWidgets('an over-budget plan says how far over only once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final container = await open(tester, mockOverBudgetTripId);
      final cost = container
          .read(tripPlanViewProvider(mockOverBudgetTripId))
          .value!
          .plan
          .cost;
      final amount = amountOf(cost);

      expect(find.textContaining(amount), findsOneWidget);
      expect(find.bySemanticsLabel(amount), findsOneWidget);
      expect(find.text('อยู่ในงบ'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a plan with nothing to cut still says it only once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // The mock plan as a day trip on the cheapest local transport, with a
      // budget the cheapest day trip fits: no night to move, no day to drop.
      late final String tripId;
      await tester.runAsync(() async {
        final catalog = await container.read(placeCatalogProvider.future);
        final calculator = await container.read(costCalculatorProvider.future);
        final advisor = await container.read(overBudgetAdvisorProvider.future);
        final mock = await container.read(mockTripPlanProvider.future);
        final mockRequest = await container.read(
          mockTripRequestProvider.future,
        );
        final dayTrip = mock.copyWith(
          days: [mock.days.first],
          nightStays: const [],
        );
        TripPlan priced(TripRequest request) => calculator.applyCosts(
          request: request,
          plan: dayTrip,
          catalog: catalog,
        );

        var request = mockRequest.copyWith(endDate: mockRequest.startDate);
        for (final mode in LocalTransportMode.values) {
          final other = request.copyWith(localTransportMode: mode);
          if (priced(other).cost.total < priced(request).cost.total) {
            request = other;
          }
        }
        final minimum = calculator.minimumTripCost(
          request: request,
          province: catalog.province(dayTrip.destinationId),
        );
        request = request.copyWith(budget: (minimum / 100).ceil() * 100);
        final plan = priced(request);
        tripId = container
            .read(draftTripsProvider.notifier)
            .add(
              plan.copyWith(
                overBudgetAdvice: advisor.advise(
                  request: request,
                  plan: plan,
                  catalog: catalog,
                ),
              ),
              request,
            );
      });
      await open(tester, tripId, within: container);

      final plan = container.read(tripPlanViewProvider(tripId)).value!.plan;
      final rescue = container.read(budgetRescueProvider(tripId)).value!;
      expect(plan.status, PlanStatus.overBudget);
      expect(
        plan.overBudgetAdvice.where(
          (item) => item.kind != BudgetAdviceKind.changeDestination,
        ),
        isEmpty,
      );
      // Nothing was applied, so the rescue is left with the banner's amount.
      expect(rescue.stillOverBy, plan.cost.overBy);
      expect(rescue.minimumBudget, lessThanOrEqualTo(plan.cost.budget));

      final amount = amountOf(plan.cost);
      expect(find.byType(BudgetRescueCard), findsOneWidget);
      expect(find.textContaining(amount), findsOneWidget);
      expect(find.bySemanticsLabel(amount), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a plan within budget gets none of them', (tester) async {
      final container = await open(tester, mockTripId);

      expect(container.read(budgetRescueProvider(mockTripId)).value, isNull);
      expect(find.byType(OverBudgetBanner), findsNothing);
      expect(find.byType(BudgetAdviceList), findsNothing);
      expect(find.byType(BudgetRescueCard), findsNothing);
      expect(find.text('อยู่ในงบ'), findsOneWidget);
      expect(find.textContaining('เกินงบ'), findsNothing);
    });
  });
}
