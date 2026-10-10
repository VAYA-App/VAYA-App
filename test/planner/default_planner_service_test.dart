import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/ai/mock_gemini_service.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/cost_calculator.dart';
import 'package:vaya_app/planner/default_planner_service.dart';
import 'package:vaya_app/planner/over_budget_advisor.dart';
import 'package:vaya_app/planner/place_selector.dart';
import 'package:vaya_app/planner/planner_service.dart';
import 'package:vaya_app/planner/slot_template.dart';

import 'test_data.dart';

/// Stands in for #34: a flat price per Stop, so totals are predictable.
class _FlatCost implements CostCalculator {
  _FlatCost(this.perStop);
  final int perStop;

  @override
  TripPlan applyCosts({
    required TripRequest request,
    required TripPlan plan,
    required PlaceCatalog catalog,
  }) {
    final stops = plan.days.expand((d) => d.stops).length;
    final total = stops * perStop;
    final cost = CostEstimate(
      intercity: 0,
      accommodation: 0,
      food: 0,
      entrance: total,
      localTransport: 0,
      buffer: 0,
      total: total,
      perPerson: (total / request.travellerCount).ceil(),
      budget: request.budget,
    );
    return plan.copyWith(
      cost: cost,
      status: cost.isOverBudget ? PlanStatus.overBudget : PlanStatus.ok,
    );
  }

  @override
  int minimumTripCost({
    required TripRequest request,
    required Province province,
  }) => 0;
}

/// Stands in for #37.
class _Advisor implements OverBudgetAdvisor {
  int calls = 0;

  @override
  List<BudgetAdvice> advise({
    required TripRequest request,
    required TripPlan plan,
    required PlaceCatalog catalog,
  }) {
    calls++;
    return const [
      BudgetAdvice(
        kind: BudgetAdviceKind.changeLocalTransport,
        saving: 500,
        description: 'ใช้รถสาธารณะ',
      ),
    ];
  }
}

void main() {
  final catalog = sampleCatalog();
  final fixture = readJson('test/fixtures/select_places_chonburi_2d.json');

  Future<List<PlanningProgress>> run(
    TripRequest request, {
    String destination = 'chonburi',
    MockGeminiResponder? gemini,
    int perStop = 100,
    _Advisor? advisor,
    PlaceCatalog? data,
  }) => DefaultPlannerService(
    loadCatalog: () async => data ?? catalog,
    selector: PlaceSelector(gemini: MockGeminiService(responder: gemini)),
    costCalculator: _FlatCost(perStop),
    overBudgetAdvisor: advisor ?? _Advisor(),
  ).generate(request: request, destinationId: destination).toList();

  test('reports every stage and ends with a plan', () async {
    final events = await run(demoRequest());

    expect(events.map((e) => e.stage), PlanningStage.values);
    expect(events.last.plan, isNotNull);
  });

  test('without Gemini the fallback still yields a complete plan', () async {
    final plan = (await run(demoRequest())).last.plan!;

    expect(plan.destinationId, 'chonburi');
    expect(plan.days, hasLength(2));
    for (final stop in plan.days.expand((d) => d.stops)) {
      expect(catalog.place(stop.placeId).provinceId, 'chonburi');
    }
    expect(plan.nightStays.single.night, 1);
    expect(plan.intercity?.mode, IntercityMode.bus);
    expect(plan.intercity?.durationMin, 150);
  });

  test('a route without the chosen mode uses the mode it has', () async {
    final chonburi = catalog.province('chonburi');
    final busOnly = PlaceCatalog(
      provinces: [
        for (final p in catalog.provinces)
          if (p.id != 'chonburi')
            p
          else
            Province(
              id: p.id,
              name: p.name,
              center: p.center,
              regionTag: p.regionTag,
              tags: p.tags,
              seasonality: p.seasonality,
              seasonNote: p.seasonNote,
              intercity: {
                'bangkok': {
                  IntercityMode.bus:
                      chonburi.intercity['bangkok']![IntercityMode.bus]!,
                },
              },
            ),
      ],
      places: catalog.places.toList(),
    );
    final request = demoRequest().copyWith(
      intercityMode: () => IntercityMode.car,
    );

    final plan = (await run(request, data: busOnly)).last.plan!;

    expect(plan.intercity?.mode, IntercityMode.bus);
    expect(plan.intercity?.durationMin, 150);
  });

  test('uses Gemini picks when they are valid', () async {
    final plan = (await run(
      demoRequest(),
      gemini: (_, _) => fixture,
    )).last.plan!;
    final picked = {
      for (final day in fixture['days'] as List)
        for (final s in (day as Map)['slots'] as List) (s as Map)['placeId'],
    };

    expect({
      for (final s in plan.days.expand((d) => d.stops)) s.placeId,
    }, picked);
    expect(
      plan.days.first.stops.first.note,
      'ปราสาทไม้ริมทะเล เหมาะกับสายถ่ายรูป',
    );
  });

  test(
    'day one starts on arrival and the last day respects the return trip',
    () async {
      final plan = (await run(
        demoRequest(),
        gemini: (_, _) => fixture,
      )).last.plan!;
      final first = plan.days.first.stops.first;
      final last = plan.days.last;

      expect(first.start.isBefore(const ClockTime.hm(10, 30)), isFalse);
      expect(last.stops.any((s) => s.slot == Slot.dinner), isFalse);
      expect(SlotTemplate.returnDeparture, const ClockTime.hm(17, 0));
    },
  );

  test('over budget plans get advice', () async {
    final advisor = _Advisor();
    final plan = (await run(
      demoRequest(budget: 100),
      perStop: 1000,
      advisor: advisor,
    )).last.plan!;

    expect(plan.status, PlanStatus.overBudget);
    expect(advisor.calls, 1);
    expect(plan.overBudgetAdvice.single.saving, 500);
  });

  test('plans within budget skip the advisor', () async {
    final advisor = _Advisor();
    final plan = (await run(
      demoRequest(budget: 100000),
      advisor: advisor,
    )).last.plan!;

    expect(plan.status, PlanStatus.ok);
    expect(advisor.calls, 0);
    expect(plan.overBudgetAdvice, isEmpty);
  });

  test(
    'a day trip inside the origin has no intercity leg and no hotel',
    () async {
      final request = TripRequest(
        startDate: DateTime(2026, 11, 14),
        endDate: DateTime(2026, 11, 14),
        travellerCount: 1,
        budget: 1500,
        originId: 'bangkok',
        destinationId: 'bangkok',
        localTransportMode: LocalTransportMode.publicTransport,
        preferenceTags: const {PreferenceTag.templeHistory},
        pace: Pace.normal,
      );
      final plan = (await run(request, destination: 'bangkok')).last.plan!;

      expect(plan.intercity, isNull);
      expect(plan.nightStays, isEmpty);
      expect(plan.days.single.stops, isNotEmpty);
      expect(
        plan.days.single.stops.first.start.isBefore(SlotTemplate.dayStart),
        isFalse,
      );
    },
  );
}
