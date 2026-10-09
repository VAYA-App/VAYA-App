import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/ai/mock_gemini_service.dart';
import 'package:vaya_app/app/providers/planner_providers.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/default_cost_calculator.dart';
import 'package:vaya_app/planner/default_over_budget_advisor.dart';
import 'package:vaya_app/planner/default_planner_service.dart';
import 'package:vaya_app/planner/place_selector.dart';
import 'package:vaya_app/planner/pricing_table.dart';

import 'test_data.dart';

const _center = GeoPoint(13, 100);

Province _province(String id, {int? fareFromHome, bool rainy = false}) =>
    Province(
      id: id,
      name: id,
      center: _center,
      regionTag: 'test',
      tags: const [],
      seasonality: List.filled(
        12,
        rainy ? SeasonRating.avoid : SeasonRating.good,
      ),
      seasonNote: '',
      intercity: {
        if (fareFromHome != null)
          'home': {
            IntercityMode.bus: IntercityOption(
              durationMin: 60,
              farePerPerson: fareFromHome,
            ),
          },
      },
    );

Place _place(
  String id,
  PlaceCategory category, {
  int level = 1,
  bool breakfast = false,
  GeoPoint at = _center,
}) => Place(
  id: id,
  provinceId: 'dest',
  category: category,
  name: id,
  location: at,
  tags: const [],
  priceLevel: level,
  shortDescription: '',
  breakfastIncluded: breakfast,
);

/// `dest` costs 100 a ticket, `cheap` 10 and `rainy` 1, but `rainy` is to
/// be avoided all year.
PlaceCatalog _catalog({bool withCheaperProvinces = true}) => PlaceCatalog(
  provinces: [
    _province('home'),
    _province('dest', fareFromHome: 100),
    if (withCheaperProvinces) ...[
      _province('cheap', fareFromHome: 10),
      _province('rainy', fareFromHome: 1, rainy: true),
    ],
  ],
  places: [
    _place('free', PlaceCategory.attraction),
    _place('meal1', PlaceCategory.restaurant),
    _place('hotel3', PlaceCategory.accommodation, level: 3, breakfast: true),
    _place(
      'hotel2near',
      PlaceCategory.accommodation,
      level: 2,
      at: const GeoPoint(13.001, 100.001),
    ),
    _place(
      'hotel2far',
      PlaceCategory.accommodation,
      level: 2,
      at: const GeoPoint(13.2, 100.2),
    ),
    _place('hotel1', PlaceCategory.accommodation),
  ],
);

Stop _stop(String placeId) => Stop(
  placeId: placeId,
  slot: Slot.morning,
  start: const ClockTime.hm(9, 0),
  durationMin: 60,
  travelFromPrevMin: 0,
  travelFromPrevKm: 10,
  cost: 0,
);

TripRequest _request({
  int days = 3,
  int budget = 1,
  LocalTransportMode local = LocalTransportMode.taxi,
}) => TripRequest(
  startDate: DateTime(2026, 11, 14),
  endDate: DateTime(2026, 11, 14 + days - 1),
  travellerCount: 2,
  budget: budget,
  originId: 'home',
  destinationId: 'dest',
  intercityMode: IntercityMode.bus,
  localTransportMode: local,
  preferenceTags: const {},
  pace: Pace.normal,
);

void main() {
  const calculator = DefaultCostCalculator(section9Pricing);
  const advisor = DefaultOverBudgetAdvisor(calculator);
  final catalog = _catalog();

  /// A priced plan for [request]: two Stops a day, every night at [hotel].
  TripPlan plan(
    TripRequest request, {
    String hotel = 'hotel3',
    PlaceCatalog? inCatalog,
  }) => calculator.applyCosts(
    request: request,
    catalog: inCatalog ?? catalog,
    plan: TripPlan(
      destinationId: 'dest',
      status: PlanStatus.ok,
      intercity: const IntercityLeg(
        mode: IntercityMode.bus,
        durationMin: 60,
        cost: 0,
      ),
      nightStays: [
        for (var night = 1; night < request.dayCount; night++)
          NightStay(night: night, placeId: hotel, rooms: 1, cost: 0),
      ],
      days: [
        for (var i = 0; i < request.dayCount; i++)
          DayPlan(
            date: DateTime(2026, 11, 14 + i),
            stops: [_stop('free'), _stop('meal1')],
          ),
      ],
      cost: CostEstimate.unpriced(request.budget),
    ),
  );

  int total(TripRequest request, TripPlan plan, [PlaceCatalog? inCatalog]) =>
      calculator
          .applyCosts(
            request: request,
            plan: plan,
            catalog: inCatalog ?? catalog,
          )
          .cost
          .total;

  List<BudgetAdvice> advise(
    TripRequest request,
    TripPlan plan, [
    PlaceCatalog? inCatalog,
  ]) => advisor.advise(
    request: request,
    plan: plan,
    catalog: inCatalog ?? catalog,
  );

  BudgetAdvice? of(List<BudgetAdvice> advice, BudgetAdviceKind kind) =>
      advice.where((a) => a.kind == kind).firstOrNull;

  test('a plan within budget gets no advice and no rescue', () {
    final request = _request(budget: 1000000);
    final within = plan(request);

    expect(within.status, PlanStatus.ok);
    expect(advise(request, within), isEmpty);
    expect(
      advisor.rescue(request: request, plan: within, catalog: catalog),
      isNull,
    );
  });

  group('downgrade accommodation', () {
    // Only this option and the shorter trip remain: no cheaper province.
    final local = _catalog(withCheaperProvinces: false);

    test('moves to the closest hotel one Price Level down', () {
      final request = _request(local: LocalTransportMode.publicTransport);
      final over = plan(request, inCatalog: local);
      final cheaper = over.copyWith(
        nightStays: [
          for (final n in over.nightStays) n.copyWith(placeId: 'hotel2near'),
        ],
      );

      final advice = of(
        advise(request, over, local),
        BudgetAdviceKind.downgradeAccommodation,
      )!;

      expect(advice.saving, over.cost.total - total(request, cheaper, local));
      expect(advice.description, contains('hotel2near (฿฿)'));
      // The new hotel has no breakfast, the old one had.
      expect(advice.description, contains('ไม่รวมอาหารเช้า'));
      // The saving is written with thousands separators.
      expect(advice.saving, greaterThan(999));
      final written = RegExp(
        r'ประหยัด ~฿(\d{1,3}(,\d{3})+)$',
      ).firstMatch(advice.description)!.group(1)!;
      expect(written.replaceAll(',', ''), '${advice.saving}');
    });

    test('is not offered at the cheapest hotel or on a day trip', () {
      final request = _request();
      expect(
        of(
          advise(request, plan(request, hotel: 'hotel1')),
          BudgetAdviceKind.downgradeAccommodation,
        ),
        isNull,
      );

      final dayTrip = _request(days: 1);
      expect(
        of(
          advise(dayTrip, plan(dayTrip)),
          BudgetAdviceKind.downgradeAccommodation,
        ),
        isNull,
      );
    });
  });

  group('change local transport', () {
    test('offers the mode that makes the plan cheapest', () {
      final request = _request();
      final over = plan(request);
      final totals = {
        for (final mode in LocalTransportMode.values)
          mode: total(request.copyWith(localTransportMode: mode), over),
      };
      final cheapest = totals.entries.reduce(
        (a, b) => a.value <= b.value ? a : b,
      );

      final advice = of(
        advise(request, over),
        BudgetAdviceKind.changeLocalTransport,
      )!;

      expect(cheapest.key, isNot(LocalTransportMode.taxi));
      expect(advice.saving, over.cost.total - cheapest.value);
      expect(advice.description, contains('เปลี่ยนเป็น${cheapest.key.label}'));
    });

    test('is not offered when the plan already uses the cheapest', () {
      final taxi = _request();
      final totals = {
        for (final mode in LocalTransportMode.values)
          mode: total(taxi.copyWith(localTransportMode: mode), plan(taxi)),
      };
      final cheapest = totals.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;
      final request = _request(local: cheapest);

      expect(
        of(
          advise(request, plan(request)),
          BudgetAdviceKind.changeLocalTransport,
        ),
        isNull,
      );
    });
  });

  group('remove a day', () {
    test('prices the plan without its last day and night', () {
      final request = _request();
      final over = plan(request);
      final shorter = over.copyWith(
        days: over.days.sublist(0, 2),
        nightStays: over.nightStays.sublist(0, 1),
      );

      final advice = of(advise(request, over), BudgetAdviceKind.removeDay)!;

      expect(
        advice.saving,
        over.cost.total - total(_request(days: 2), shorter),
      );
      expect(advice.description, startsWith('ลดเหลือ 2 วัน 1 คืน'));
    });

    test('a two-day trip becomes a day trip, a day trip has no option', () {
      final twoDays = _request(days: 2);
      expect(
        of(
          advise(twoDays, plan(twoDays)),
          BudgetAdviceKind.removeDay,
        )!.description,
        startsWith('ลดเหลือ 1 วัน ไม่ค้างคืน'),
      );

      final dayTrip = _request(days: 1);
      expect(
        of(advise(dayTrip, plan(dayTrip)), BudgetAdviceKind.removeDay),
        isNull,
      );
    });
  });

  group('change destination', () {
    test('compares the cheapest trip here with the cheapest elsewhere', () {
      final request = _request(days: 1);
      final advice = of(
        advise(request, plan(request)),
        BudgetAdviceKind.changeDestination,
      )!;

      int minimum(String id) => calculator.minimumTripCost(
        request: request,
        province: catalog.province(id),
      );
      expect(advice.saving, minimum('dest') - minimum('cheap'));
      // `rainy` is cheaper still, but out of season.
      expect(minimum('rainy'), lessThan(minimum('cheap')));
      expect(advice.description, contains('เที่ยวcheapแทน'));
    });

    test('is not offered when nowhere is cheaper', () {
      final local = _catalog(withCheaperProvinces: false);
      final request = _request();

      expect(
        of(
          advise(request, plan(request, inCatalog: local), local),
          BudgetAdviceKind.changeDestination,
        ),
        isNull,
      );
    });
  });

  group('ranking', () {
    test('at most three, largest saving first, nothing that saves nothing', () {
      final request = _request();
      final advice = advise(request, plan(request));

      expect(advice, hasLength(DefaultOverBudgetAdvisor.maxAdvice));
      expect(advice.every((a) => a.saving > 0), isTrue);
      final savings = advice.map((a) => a.saving).toList();
      expect(savings, [...savings]..sort((a, b) => b.compareTo(a)));
    });

    test('the destination estimate comes after every priced option', () {
      // A day trip has two priced options at most, so the estimate fits.
      final request = _request(days: 1);
      final advice = advise(request, plan(request));

      expect(advice.last.kind, BudgetAdviceKind.changeDestination);
      expect(advice.length, greaterThan(1));
    });

    test('does not change the plan it was given', () {
      final request = _request();
      final over = plan(request);
      final before = over.toJson();

      advise(request, over);
      advisor.rescue(request: request, plan: over, catalog: catalog);

      expect(over.toJson(), before);
    });
  });

  group('rescue', () {
    test('reports what is left after every option is applied at once', () {
      final request = _request();
      final over = plan(request);
      // Cheaper hotel, then the cheapest transport for that plan, then one
      // day fewer: priced as one plan, never by adding savings up.
      final moved = over.copyWith(
        nightStays: [
          for (final n in over.nightStays) n.copyWith(placeId: 'hotel2near'),
        ],
      );
      final mode = LocalTransportMode.values.reduce(
        (a, b) =>
            total(request.copyWith(localTransportMode: a), moved) <=
                total(request.copyWith(localTransportMode: b), moved)
            ? a
            : b,
      );
      final all = total(
        _request(days: 2, local: mode),
        moved.copyWith(
          days: moved.days.sublist(0, 2),
          nightStays: moved.nightStays.sublist(0, 1),
        ),
      );

      final rescue = advisor.rescue(
        request: request,
        plan: over,
        catalog: catalog,
      )!;
      final minimum = calculator.minimumTripCost(
        request: request,
        province: catalog.province('dest'),
      );

      expect(rescue.stillOverBy, all - request.budget);
      expect(rescue.minimumBudget % 100, 0);
      expect(rescue.minimumBudget, inInclusiveRange(minimum, minimum + 99));
      // One baht covers no trip at all.
      expect(rescue.daysThatFit, isNull);
      expect(rescue.costOfDaysThatFit, isNull);
    });

    test('names the longest trip the budget can cover', () {
      int minimum(int days) => calculator.minimumTripCost(
        request: _request(days: days),
        province: catalog.province('dest'),
      );
      // Enough for two days at the very cheapest, not for three.
      final request = _request(budget: minimum(2));

      final rescue = advisor.rescue(
        request: request,
        plan: plan(request),
        catalog: catalog,
      )!;

      expect(minimum(2), lessThan(minimum(3)));
      expect(rescue.daysThatFit, 2);
      expect(rescue.costOfDaysThatFit, minimum(2));
    });

    test('is not needed when the options together fit the budget', () {
      final probe = _request();
      final over = plan(probe);
      // One baht short of the plan as it is: any option brings it back.
      final request = _request(budget: over.cost.total - 1);
      final justOver = plan(request);

      expect(justOver.status, PlanStatus.overBudget);
      expect(advise(request, justOver), isNotEmpty);
      expect(
        advisor.rescue(request: request, plan: justOver, catalog: catalog),
        isNull,
      );
    });
  });

  group('with the bundled data', () {
    final sample = sampleCatalog();
    final real = DefaultCostCalculator(
      PricingTable.fromJson(readJson('assets/data/pricing.json')),
    );

    test(
      'demo 3 (Chonburi, 3 days, 4 people, ฿3,000) gets priced advice',
      () async {
        final request = TripRequest(
          startDate: DateTime(2026, 11, 14),
          endDate: DateTime(2026, 11, 16),
          travellerCount: 4,
          budget: 3000,
          originId: 'bangkok',
          intercityMode: IntercityMode.bus,
          localTransportMode: LocalTransportMode.taxi,
          preferenceTags: const {PreferenceTag.beach, PreferenceTag.seafood},
          pace: Pace.chill,
        );
        final planner = DefaultPlannerService(
          loadCatalog: () async => sample,
          selector: PlaceSelector(gemini: MockGeminiService()),
          costCalculator: real,
          overBudgetAdvisor: DefaultOverBudgetAdvisor(real),
        );

        final done = await planner
            .generate(request: request, destinationId: 'chonburi')
            .last;
        final over = done.plan!;
        final advice = over.overBudgetAdvice;
        int reprice(TripRequest r, TripPlan p) =>
            real.applyCosts(request: r, plan: p, catalog: sample).cost.total;

        expect(over.status, PlanStatus.overBudget);
        expect(advice.length, greaterThanOrEqualTo(2));

        final shorter = of(advice, BudgetAdviceKind.removeDay)!;
        expect(
          shorter.saving,
          over.cost.total -
              reprice(
                request.copyWith(endDate: DateTime(2026, 11, 15)),
                over.copyWith(
                  days: over.days.sublist(0, 2),
                  nightStays: over.nightStays.sublist(0, 1),
                ),
              ),
        );

        final transport = of(advice, BudgetAdviceKind.changeLocalTransport)!;
        final cheapest = LocalTransportMode.values
            .map((m) => reprice(request.copyWith(localTransportMode: m), over))
            .reduce((a, b) => a < b ? a : b);
        expect(transport.saving, over.cost.total - cheapest);

        // Even together the options leave this trip far over ฿3,000.
        final rescue = DefaultOverBudgetAdvisor(
          real,
        ).rescue(request: request, plan: over, catalog: sample)!;
        expect(rescue.stillOverBy, greaterThan(0));
        expect(rescue.minimumBudget, greaterThan(request.budget));
      },
    );
  });

  test('the providers hand the real advisor to the pipeline', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(overBudgetAdvisorProvider.future),
      isA<DefaultOverBudgetAdvisor>(),
    );
    expect(
      await container.read(pipelinePlannerServiceProvider.future),
      isA<DefaultPlannerService>(),
    );
  });
}
