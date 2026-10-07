import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/default_cost_calculator.dart';
import 'package:vaya_app/planner/geo.dart';
import 'package:vaya_app/planner/pricing_table.dart';

import 'test_data.dart';

/// PROJECT-PLAN §9, kept here so these tests do not move with pricing.json.
const _pricing = PricingTable(
  roomPerNight: {1: 700, 2: 1500, 3: 3000, 4: 6000},
  mealPerPerson: {1: 80, 2: 200, 3: 450, 4: 1000},
  breakfastPerPerson: 100,
  localTransport: {
    LocalTransportMode.rentalCar: LocalTransportRate(
      perDay: 1000,
      perKm: 2.5,
      capacity: 4,
    ),
    LocalTransportMode.rentalMotorbike: LocalTransportRate(
      perDay: 250,
      perKm: 1,
      capacity: 2,
    ),
    LocalTransportMode.taxi: LocalTransportRate(
      perTrip: 40,
      perKm: 12,
      capacity: 4,
    ),
    LocalTransportMode.publicTransport: LocalTransportRate(perTrip: 30),
  },
  selfDrivePerKm: 2.5,
  bufferRate: 0.1,
);

const _center = GeoPoint(13, 100);
const _far = GeoPoint(13.05, 100.05);

Province _province(String id, {String? reachedFrom}) => Province(
  id: id,
  name: id,
  center: _center,
  regionTag: 'test',
  tags: const [],
  seasonality: List.filled(12, SeasonRating.good),
  seasonNote: '',
  intercity: {
    ?reachedFrom: const {
      IntercityMode.bus: IntercityOption(durationMin: 60, farePerPerson: 100),
      IntercityMode.train: IntercityOption(durationMin: 90, farePerPerson: 40),
      IntercityMode.car: IntercityOption(
        durationMin: 50,
        distanceKm: 101,
        toll: 50,
      ),
    },
  },
);

Place _place(
  String id,
  PlaceCategory category, {
  int level = 1,
  int fee = 0,
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
  entranceFee: fee,
  breakfastIncluded: breakfast,
);

final _catalog = PlaceCatalog(
  provinces: [
    _province('home'),
    _province('dest', reachedFrom: 'home'),
  ],
  places: [
    _place('free', PlaceCategory.attraction),
    _place('paid', PlaceCategory.attraction, fee: 150),
    _place('meal1', PlaceCategory.restaurant),
    _place('meal3', PlaceCategory.restaurant, level: 3),
    _place('hotel2', PlaceCategory.accommodation, level: 2),
    _place('hotel3b', PlaceCategory.accommodation, level: 3, breakfast: true),
    _place('hotelFar', PlaceCategory.accommodation, at: _far),
  ],
);

Stop _stop(String placeId, {double km = 0}) => Stop(
  placeId: placeId,
  slot: Slot.morning,
  start: const ClockTime.hm(9, 0),
  durationMin: 60,
  travelFromPrevMin: 0,
  travelFromPrevKm: km,
  cost: 0,
);

/// An unpriced plan with one inner list of Stops per day.
TripPlan _plan(
  List<List<Stop>> days, {
  String? hotel,
  int rooms = 1,
  IntercityMode? intercity,
}) => TripPlan(
  destinationId: 'dest',
  status: PlanStatus.ok,
  intercity: intercity == null
      ? null
      : IntercityLeg(mode: intercity, durationMin: 60, cost: 0),
  nightStays: [
    if (hotel != null)
      for (var night = 1; night < days.length; night++)
        NightStay(night: night, placeId: hotel, rooms: rooms, cost: 0),
  ],
  days: [
    for (final (i, stops) in days.indexed)
      DayPlan(date: DateTime(2026, 11, 14 + i), stops: stops),
  ],
  cost: const CostEstimate.unpriced(0),
);

TripRequest _request({
  int travellers = 2,
  int days = 1,
  int budget = 1000000,
  String origin = 'dest',
  LocalTransportMode local = LocalTransportMode.publicTransport,
}) => TripRequest(
  startDate: DateTime(2026, 11, 14),
  endDate: DateTime(2026, 11, 14 + days - 1),
  travellerCount: travellers,
  budget: budget,
  originId: origin,
  destinationId: 'dest',
  localTransportMode: local,
  preferenceTags: const {},
  pace: Pace.normal,
);

void main() {
  const calculator = DefaultCostCalculator(_pricing);

  TripPlan price(TripRequest request, TripPlan plan) =>
      calculator.applyCosts(request: request, plan: plan, catalog: _catalog);

  group('accommodation', () {
    test('charges every room for every night', () {
      for (final (travellers, rooms) in [(1, 1), (2, 1), (3, 2), (5, 3)]) {
        final priced = price(
          _request(travellers: travellers, days: 3),
          _plan(
            [
              [_stop('free')],
              [_stop('free')],
              [_stop('free')],
            ],
            hotel: 'hotel2',
            rooms: rooms,
          ),
        );

        expect(priced.nightStays.map((n) => n.cost), [
          1500 * rooms,
          1500 * rooms,
        ]);
        expect(priced.cost.accommodation, 1500 * rooms * 2);
      }
    });

    test('a one-day trip has none', () {
      final priced = price(
        _request(),
        _plan([
          [_stop('free')],
        ]),
      );

      expect(priced.cost.accommodation, 0);
    });

    test('a night without accommodation data still costs a room', () {
      // 500 baht per person per day allows Price Level 1 only.
      for (final (travellers, rooms) in [(1, 1), (2, 1), (3, 2), (5, 3)]) {
        final priced = price(
          _request(travellers: travellers, days: 2, budget: 1000 * travellers),
          _plan([
            [_stop('free')],
            [_stop('free')],
          ]),
        );

        expect(priced.nightStays, isEmpty);
        expect(priced.cost.accommodation, 700 * rooms);
      }
    });
  });

  group('food', () {
    test('prices each meal by the restaurant Price Level', () {
      final priced = price(
        _request(travellers: 3),
        _plan([
          [_stop('meal1'), _stop('meal3')],
        ]),
      );

      expect(priced.days.single.stops.map((s) => s.cost), [240, 1350]);
      // Plus one breakfast each.
      expect(priced.cost.food, 240 + 1350 + 300);
      expect(priced.cost.entrance, 0);
    });

    test('adds breakfast for every day the accommodation leaves out', () {
      final days = [
        [_stop('free')],
        [_stop('free')],
        [_stop('free')],
      ];

      final notIncluded = price(
        _request(days: 3),
        _plan(days, hotel: 'hotel2'),
      );
      expect(notIncluded.cost.food, 100 * 2 * 3);

      // Two mornings at the hotel are covered; the first day is not.
      final included = price(_request(days: 3), _plan(days, hotel: 'hotel3b'));
      expect(included.cost.food, 100 * 2 * 1);
    });
  });

  group('entrance', () {
    test('charges the fee per traveller and nothing when there is none', () {
      final priced = price(
        _request(travellers: 5),
        _plan([
          [_stop('paid'), _stop('free')],
        ]),
      );

      expect(priced.days.single.stops.map((s) => s.cost), [750, 0]);
      expect(priced.cost.entrance, 750);
    });
  });

  group('local transport', () {
    // Three Stops and the way back to the hotel: 4 legs, 19.5 km, 2 days.
    TripPlan twoDays() => _plan([
      [_stop('free', km: 10), _stop('meal1', km: 5)],
      [_stop('paid', km: 4.5)],
    ], hotel: 'hotel2');

    int cost(LocalTransportMode mode, int travellers) => price(
      _request(travellers: travellers, days: 2, local: mode),
      twoDays(),
    ).cost.localTransport;

    test('rental car: per day and per km for each car of 4', () {
      // 1000 × 2 + 2.5 × 19.5 = 2048.75
      expect([1, 2, 3, 5].map((n) => cost(LocalTransportMode.rentalCar, n)), [
        2049,
        2049,
        2049,
        4098,
      ]);
    });

    test('rental motorbike: per day and per km for each bike of 2', () {
      // 250 × 2 + 1 × 19.5 = 519.5
      expect(
        [1, 2, 3, 5].map((n) => cost(LocalTransportMode.rentalMotorbike, n)),
        [520, 520, 1039, 1559],
      );
    });

    test('taxi: flag fall per leg and per km for each car of 4', () {
      // 40 × 4 + 12 × 19.5 = 394
      expect([1, 2, 3, 5].map((n) => cost(LocalTransportMode.taxi, n)), [
        394,
        394,
        394,
        788,
      ]);
    });

    test('public transport: a fare per leg for each traveller', () {
      // 30 × 4 = 120
      expect(
        [1, 2, 3, 5].map((n) => cost(LocalTransportMode.publicTransport, n)),
        [120, 240, 360, 600],
      );
    });

    test('returns to the accommodation every night but the last day', () {
      final priced = price(
        _request(travellers: 1, days: 3),
        _plan([
          [_stop('free')],
          [_stop('free')],
          [_stop('free')],
        ], hotel: 'hotel2'),
      );

      // 3 Stops + 2 returns.
      expect(priced.cost.localTransport, 30 * 5);
    });

    test('a one-day trip returns to where it started', () {
      final priced = price(
        _request(travellers: 1),
        _plan([
          [_stop('free'), _stop('meal1')],
        ]),
      );

      expect(priced.cost.localTransport, 30 * 3);
    });

    test('measures the way back to the accommodation', () {
      final back = travelBetween(_center, _far).km;
      expect(back, greaterThan(0));

      final priced = price(
        _request(travellers: 1, days: 2, local: LocalTransportMode.taxi),
        _plan([
          [_stop('free', km: 3)],
          [_stop('paid', km: 2)],
        ], hotel: 'hotelFar'),
      );

      expect(priced.cost.localTransport, (40 * 3 + 12 * (5 + back)).round());
    });

    test('a rental is paid for every day of the trip', () {
      final priced = price(
        _request(
          travellers: 1,
          days: 3,
          local: LocalTransportMode.rentalMotorbike,
        ),
        _plan([
          [_stop('free')],
          [_stop('free')],
          [_stop('free')],
        ], hotel: 'hotel2'),
      );

      expect(priced.cost.localTransport, 250 * 3);
    });
  });

  group('intercity', () {
    TripPlan priced(IntercityMode mode, int travellers) => price(
      _request(travellers: travellers, origin: 'home'),
      _plan([
        [_stop('free')],
      ], intercity: mode),
    );

    test('tickets are per traveller, both ways', () {
      expect(priced(IntercityMode.bus, 3).cost.intercity, 100 * 3 * 2);
      expect(priced(IntercityMode.train, 3).cost.intercity, 40 * 3 * 2);
      expect(priced(IntercityMode.bus, 3).intercity!.cost, 600);
    });

    test('driving pays fuel and toll per direction, not per traveller', () {
      // (101 × 2.5 + 50) × 2
      expect(priced(IntercityMode.car, 1).cost.intercity, 605);
      expect(priced(IntercityMode.car, 5).cost.intercity, 605);
    });

    test('a trip inside the origin province costs nothing', () {
      final plan = price(
        _request(),
        _plan([
          [_stop('free')],
        ]),
      );

      expect(plan.intercity, isNull);
      expect(plan.cost.intercity, 0);
    });
  });

  group('totals', () {
    // intercity 400 + room 1500 + food (160 + 900 + 400) + entrance 300 +
    // local 30 × 4 legs × 2 = 3900
    TripPlan priced({int budget = 1000000}) => price(
      _request(days: 2, origin: 'home', budget: budget),
      _plan(
        [
          [_stop('paid'), _stop('meal1')],
          [_stop('meal3')],
        ],
        hotel: 'hotel2',
        intercity: IntercityMode.bus,
      ),
    );

    test('adds a 10% buffer on top of every category', () {
      final cost = priced().cost;

      expect(
        (
          cost.intercity,
          cost.accommodation,
          cost.food,
          cost.entrance,
          cost.localTransport,
        ),
        (400, 1500, 1460, 300, 240),
      );
      expect(cost.buffer, 390);
      expect(cost.total, 4290);
      expect(cost.perPerson, 2145);
    });

    test('rounds the share per person up', () {
      final cost = price(
        _request(travellers: 3, days: 2, budget: 3000),
        _plan([
          [_stop('free')],
          [_stop('free')],
        ]),
      ).cost;

      // rooms 700 × 2 + breakfast 600 + local 30 × 3 legs × 3 = 2270
      expect(cost.buffer, 227);
      expect(cost.total, 2497);
      expect(cost.perPerson, 833);
    });

    test('is over budget only when the total exceeds the budget', () {
      final within = priced(budget: 4290);
      expect(within.status, PlanStatus.ok);
      expect(within.cost.budget, 4290);

      final over = priced(budget: 4289);
      expect(over.status, PlanStatus.overBudget);
      expect(over.cost.overBy, 1);
    });

    test('stop and night costs add up to their categories', () {
      final plan = priced();
      final cost = plan.cost;
      final stops = plan.days
          .expand((d) => d.stops)
          .fold(0, (sum, s) => sum + s.cost);
      const breakfast = 100 * 2 * 2;

      expect(stops + breakfast, cost.food + cost.entrance);
      expect(plan.nightStays.single.cost, cost.accommodation);
      expect(
        cost.intercity +
            cost.accommodation +
            cost.food +
            cost.entrance +
            cost.localTransport +
            cost.buffer,
        cost.total,
      );
    });

    test('pricing a priced plan again changes nothing', () {
      final once = priced();
      final twice = price(_request(days: 2, origin: 'home'), once);

      expect(twice.toJson(), once.toJson());
    });
  });

  test('the mock trip plan matches the calculator', () {
    final real = DefaultCostCalculator(
      PricingTable.fromJson(readJson('assets/data/pricing.json')),
    );
    final request = TripRequest.fromJson(
      readJson('assets/mock/trip_request_demo.json'),
    );
    final mock = TripPlan.fromJson(
      readJson('assets/mock/trip_plan_chonburi_2d.json'),
    );
    final unpriced = mock.copyWith(
      intercity: () => IntercityLeg(
        mode: mock.intercity!.mode,
        durationMin: mock.intercity!.durationMin,
        cost: 0,
      ),
      nightStays: [for (final n in mock.nightStays) n.copyWith(cost: 0)],
      days: [
        for (final d in mock.days)
          d.copyWith(stops: [for (final s in d.stops) s.copyWith(cost: 0)]),
      ],
      cost: CostEstimate.unpriced(request.budget),
    );

    final priced = real.applyCosts(
      request: request,
      plan: unpriced,
      catalog: sampleCatalog(),
    );

    expect(priced.toJson(), mock.toJson());
  });
}
