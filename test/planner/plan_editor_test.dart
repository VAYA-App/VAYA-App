import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/default_cost_calculator.dart';
import 'package:vaya_app/planner/default_over_budget_advisor.dart';
import 'package:vaya_app/planner/plan_editor.dart';

import 'test_data.dart';

void main() {
  final catalog = sampleCatalog();
  const calculator = DefaultCostCalculator(section9Pricing);
  const editor = PlanEditor(
    costCalculator: calculator,
    overBudgetAdvisor: DefaultOverBudgetAdvisor(calculator),
  );
  final request = demoRequest(budget: 7000);
  final plan = calculator.applyCosts(
    request: request,
    plan: TripPlan.fromJson(readJson('assets/mock/trip_plan_chonburi_2d.json')),
    catalog: catalog,
  );
  final firstDay = plan.days.first.stops;

  List<String> ids(TripPlan p, int day) => [
    for (final s in p.days[day].stops) s.placeId,
  ];

  test('removing a stop re-times the day and lowers the cost', () {
    // The only paid attraction: ฿500 a person.
    final index = firstDay.indexWhere(
      (s) => s.placeId == 'chonburi-attraction-sanctuary-of-truth',
    );
    final edited = editor.apply(
      RemoveStop(day: 0, index: index),
      plan: plan,
      request: request,
      catalog: catalog,
    );

    expect(ids(edited, 0), isNot(contains(firstDay[index].placeId)));
    expect(edited.days.first.stops, hasLength(firstDay.length - 1));
    expect(edited.days[1].stops, hasLength(plan.days[1].stops.length));
    expect(edited.cost.entrance, 0);
    expect(edited.cost.total, lessThan(plan.cost.total));
    // Times follow on from each other again.
    final stops = edited.days.first.stops;
    for (var i = 1; i < stops.length; i++) {
      expect(stops[i].start.isBefore(stops[i - 1].end), isFalse);
    }
  });

  test('swapping keeps the slot and prices the new place', () {
    final lunch = firstDay.indexWhere((s) => s.slot == Slot.lunch);
    final options = PlanEditor.alternatives(
      plan,
      catalog,
      day: 0,
      index: lunch,
    );
    expect(options, hasLength(5));
    expect(
      options.map((p) => p.category),
      everyElement(PlaceCategory.restaurant),
    );
    expect(
      options.map((p) => p.id),
      isNot(
        anyElement(
          isIn(plan.days.expand((d) => d.stops).map((s) => s.placeId)),
        ),
      ),
    );

    final edited = editor.apply(
      ReplaceStop(day: 0, index: lunch, placeId: options.first.id),
      plan: plan,
      request: request,
      catalog: catalog,
    );
    final stop = edited.days.first.stops.firstWhere(
      (s) => s.placeId == options.first.id,
    );
    expect(stop.slot, Slot.lunch);
    expect(stop.cost, greaterThan(0));
  });

  test('alternatives are the closest first', () {
    final index = 0;
    final here = catalog.place(firstDay[index].placeId).location;
    final options = PlanEditor.alternatives(
      plan,
      catalog,
      day: 0,
      index: index,
      count: 10,
    );
    final distances = [
      for (final p in options)
        (p.location.lat - here.lat).abs() + (p.location.lng - here.lng).abs(),
    ];
    expect(
      options.map((p) => p.category),
      everyElement(PlaceCategory.attraction),
    );
    expect(distances.first, lessThanOrEqualTo(distances.last));
  });

  test('a replacement that does not fit is refused', () {
    void refuse(PlanEdit edit) => expect(
      () => editor.apply(edit, plan: plan, request: request, catalog: catalog),
      throwsArgumentError,
    );
    final lunch = firstDay.indexWhere((s) => s.slot == Slot.lunch);

    refuse(const RemoveStop(day: 5, index: 0));
    refuse(RemoveStop(day: 0, index: firstDay.length));
    refuse(ReplaceStop(day: 0, index: lunch, placeId: 'no-such-place'));
    // An attraction in a meal slot.
    refuse(
      ReplaceStop(
        day: 0,
        index: lunch,
        placeId: 'chonburi-attraction-koh-larn',
      ),
    );
    // Another province.
    refuse(
      ReplaceStop(
        day: 0,
        index: lunch,
        placeId: 'bangkok-restaurant-thipsamai',
      ),
    );
    // Already in the plan.
    refuse(ReplaceStop(day: 0, index: 0, placeId: firstDay.last.placeId));
  });

  test('going over budget brings advice', () {
    final tight = demoRequest(budget: 3000);
    final edited = editor.apply(
      const RemoveStop(day: 1, index: 0),
      plan: plan,
      request: tight,
      catalog: catalog,
    );
    expect(edited.cost.isOverBudget, isTrue);
    expect(edited.overBudgetAdvice, isNotEmpty);
  });
}
