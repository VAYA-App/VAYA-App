import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/ai/mock_gemini_service.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/default_cost_calculator.dart';
import 'package:vaya_app/planner/default_planner_service.dart';
import 'package:vaya_app/planner/over_budget_advisor.dart';
import 'package:vaya_app/planner/place_selector.dart';
import 'package:vaya_app/planner/pricing_table.dart';

import 'test_data.dart';

/// Every way in arrives before 11:00, so no slot of the first day is cut.
const _allModes = {
  IntercityMode.bus: IntercityOption(durationMin: 60, farePerPerson: 100),
  IntercityMode.train: IntercityOption(durationMin: 90, farePerPerson: 40),
  IntercityMode.car: IntercityOption(
    durationMin: 50,
    distanceKm: 101,
    toll: 50,
  ),
};

Province _province(Map<IntercityMode, IntercityOption> fromHome) => Province(
  id: 'dest',
  name: 'dest',
  center: const GeoPoint(13, 100),
  regionTag: 'test',
  tags: const [],
  seasonality: List.filled(12, SeasonRating.good),
  seasonNote: '',
  intercity: {'home': fromHome},
);

TripRequest _request({
  int travellers = 2,
  int days = 1,
  String origin = 'dest',
  Pace pace = Pace.normal,
  IntercityMode? intercity,
  LocalTransportMode local = LocalTransportMode.rentalCar,
}) => TripRequest(
  startDate: DateTime(2026, 11, 14),
  endDate: DateTime(2026, 11, 14 + days - 1),
  travellerCount: travellers,
  budget: 1000000,
  originId: origin,
  intercityMode: intercity,
  localTransportMode: local,
  preferenceTags: const {},
  pace: pace,
);

class _NoAdvice implements OverBudgetAdvisor {
  @override
  List<BudgetAdvice> advise({
    required TripRequest request,
    required TripPlan plan,
    required PlaceCatalog catalog,
  }) => const [];
}

void main() {
  const calculator = DefaultCostCalculator(section9Pricing);
  final dest = _province(_allModes);

  int minimum(TripRequest request, [Province? province]) =>
      calculator.minimumTripCost(request: request, province: province ?? dest);

  group('rejects a request without', () {
    test('travellers', () {
      expect(
        () => minimum(_request(travellers: 0)),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.name,
            'name',
            'request.travellerCount',
          ),
        ),
      );
    });

    test('days, instead of a negative minimum', () {
      expect(
        () => minimum(_request(days: 0, origin: 'home')),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.name,
            'name',
            'request.dayCount',
          ),
        ),
      );
    });
  });

  group('a trip inside the origin province', () {
    test('one day: no intercity, no room, one way back', () {
      // 5 slots, 2 meals: food 80 × 2 × 2 + breakfast 200 = 520
      // taxi 40 × 6 legs = 240 → 760 + 10%
      expect(minimum(_request()), 836);
    });

    test('more days add rooms, meals and the way back each night', () {
      // room 700, food 640 + 200, taxi 40 × 11 = 1980 + 10%
      expect(minimum(_request(days: 2)), 2178);
      // rooms 1400, food 960 + 200, taxi 40 × 17 = 3240 + 10%
      expect(minimum(_request(days: 3)), 3564);
    });

    test('more travellers need more rooms, vehicles and meals', () {
      expect(
        [1, 2, 3, 5].map((n) => minimum(_request(travellers: n, days: 2))),
        // 1: public 330; 2 and 3: one taxi 440; 5: two taxis 880
        [1595, 2178, 3410, 5588],
      );
    });

    test('ignores the Local Transport Mode the user picked', () {
      expect(
        {
          for (final mode in LocalTransportMode.values)
            minimum(_request(local: mode)),
        },
        {836},
      );
    });

    test('a fuller Pace costs more', () {
      final byPace = [
        for (final pace in Pace.values) minimum(_request(pace: pace)),
      ];

      expect(byPace, [...byPace]..sort());
      expect(byPace.toSet(), hasLength(Pace.values.length));
    });
  });

  group('a trip to another province', () {
    test('adds the cheapest way there', () {
      // 4 slots, 1 meal: food 180, public 30 × 5 = 150, train 80 → 410 + 10%
      expect(minimum(_request(travellers: 1, origin: 'home')), 451);
      // 5 travellers: food 900, two taxis 400, train 400 → 1700 + 10%
      expect(minimum(_request(travellers: 5, origin: 'home')), 1870);
    });

    test('uses another mode when it is the only one', () {
      final busOnly = _province({
        IntercityMode.bus: _allModes[IntercityMode.bus]!,
      });

      // bus 200 instead of train 80 → 530 + 10%
      expect(minimum(_request(travellers: 1, origin: 'home'), busOnly), 583);
    });

    test('ignores the Intercity Transport the user picked', () {
      expect(
        minimum(
          _request(travellers: 1, origin: 'home', intercity: IntercityMode.car),
        ),
        451,
      );
    });

    test('a late arrival leaves fewer slots to pay for', () {
      // Arrives 12:00: the morning slot is gone. 3 slots, 1 meal:
      // food 180, public 30 × 4 = 120, train 80 → 380 + 10%
      final slowTrain = _province({
        IntercityMode.train: const IntercityOption(
          durationMin: 240,
          farePerPerson: 40,
        ),
      });

      expect(minimum(_request(travellers: 1, origin: 'home'), slowTrain), 418);
    });

    test('a route without fare data costs nothing to reach', () {
      expect(minimum(_request(origin: 'elsewhere')), minimum(_request()));
    });
  });

  group('with the bundled data', () {
    final catalog = sampleCatalog();
    final real = DefaultCostCalculator(
      PricingTable.fromJson(readJson('assets/data/pricing.json')),
    );

    // No baht amount here: fares and prices in the bundled files change
    // as the data is checked (#20, #22). The worked figures are in the
    // groups above, on data this file owns.
    test('demo trip: the cheapest of the ways the route offers', () {
      final request = TripRequest.fromJson(
        readJson('assets/mock/trip_request_demo.json'),
      );
      final chonburi = catalog.province('chonburi');
      int minimumIn(Province province) =>
          real.minimumTripCost(request: request, province: province);

      final byMode = {
        for (final MapEntry(key: mode, value: option)
            in chonburi.intercity[request.originId]!.entries)
          mode: minimumIn(
            Province(
              id: chonburi.id,
              name: chonburi.name,
              center: chonburi.center,
              regionTag: chonburi.regionTag,
              tags: chonburi.tags,
              seasonality: chonburi.seasonality,
              seasonNote: chonburi.seasonNote,
              intercity: {
                request.originId: {mode: option},
              },
            ),
          ),
      };

      expect(byMode.keys, containsAll(IntercityMode.values));
      expect(byMode.values.toSet().length, greaterThan(1));
      expect(minimumIn(chonburi), byMode.values.reduce(math.min));
    });

    test('is never above a plan the pipeline builds', () async {
      final planner = DefaultPlannerService(
        loadCatalog: () async => catalog,
        selector: PlaceSelector(gemini: MockGeminiService()),
        costCalculator: real,
        overBudgetAdvisor: _NoAdvice(),
      );

      final requests = [
        for (final origin in ['bangkok', 'chonburi'])
          for (final pace in Pace.values)
            for (final travellers in [1, 2, 5])
              for (final days in [1, 2, 3])
                for (final intercity in IntercityMode.values)
                  for (final local in LocalTransportMode.values)
                    _request(
                      travellers: travellers,
                      days: days,
                      origin: origin,
                      pace: pace,
                      intercity: intercity,
                      local: local,
                    ),
      ];

      for (final destination in ['chonburi', 'bangkok']) {
        for (final request in requests) {
          final done = await planner
              .generate(request: request, destinationId: destination)
              .last;

          expect(
            real.minimumTripCost(
              request: request,
              province: catalog.province(destination),
            ),
            lessThanOrEqualTo(done.plan!.cost.total),
            reason: '$destination ${request.toJson()}',
          );
        }
      }
      expect(requests, hasLength(648));
    });
  });
}
