import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/cost_calculator.dart';
import 'package:vaya_app/planner/province_filter.dart';

/// Fixed minimum costs, so each case controls the budget check directly.
class _FixedCosts implements CostCalculator {
  const _FixedCosts(this.costs);

  final Map<String, int> costs;

  @override
  int minimumTripCost({
    required TripRequest request,
    required Province province,
  }) => costs[province.id]!;

  @override
  TripPlan applyCosts({
    required TripRequest request,
    required TripPlan plan,
    required PlaceCatalog catalog,
  }) => throw UnimplementedError();
}

Province _province(String id, {SeasonRating november = SeasonRating.good}) =>
    Province(
      id: id,
      name: id,
      center: const GeoPoint(13, 100),
      regionTag: 'test',
      tags: const [],
      seasonality: [
        for (var month = 1; month <= 12; month++)
          month == 11 ? november : SeasonRating.good,
      ],
      seasonNote: '',
      intercity: const {},
    );

TripRequest _request({int budget = 5000, String? destinationId}) => TripRequest(
  startDate: DateTime(2026, 11, 14),
  endDate: DateTime(2026, 11, 15),
  travellerCount: 2,
  budget: budget,
  originId: 'home',
  destinationId: destinationId,
  localTransportMode: LocalTransportMode.publicTransport,
  preferenceTags: const {PreferenceTag.beach},
  pace: Pace.normal,
);

void main() {
  PlaceCatalog catalog(List<Province> provinces) =>
      PlaceCatalog(provinces: provinces, places: const []);

  List<String> ids(List<ProvinceCandidate> candidates) => [
    for (final c in candidates) c.province.id,
  ];

  test('keeps every province that fits, cheapest first', () {
    const filter = ProvinceFilter(_FixedCosts({'a': 4800, 'b': 3200}));
    final result = filter.filter(
      request: _request(),
      catalog: catalog([_province('a'), _province('b')]),
    );

    expect(ids(result), ['b', 'a']);
    expect(result.first.minimumCost, 3200);
  });

  test('drops a province over the budget', () {
    const filter = ProvinceFilter(_FixedCosts({'a': 5001, 'b': 3200}));
    final result = filter.filter(
      request: _request(),
      catalog: catalog([_province('a'), _province('b')]),
    );

    expect(ids(result), ['b']);
  });

  test('nothing fits a budget below every minimum', () {
    const filter = ProvinceFilter(_FixedCosts({'a': 4800, 'b': 3200}));
    final result = filter.filter(
      request: _request(budget: 3000),
      catalog: catalog([_province('a'), _province('b')]),
    );

    expect(result, isEmpty);
  });

  test('drops a province to avoid in the month the trip starts', () {
    const filter = ProvinceFilter(_FixedCosts({'a': 4800, 'b': 3200}));
    final result = filter.filter(
      request: _request(),
      catalog: catalog([
        _province('a'),
        _province('b', november: SeasonRating.avoid),
      ]),
    );

    expect(ids(result), ['a']);
  });

  test('a chosen Destination is kept without filtering', () {
    const filter = ProvinceFilter(_FixedCosts({'a': 9000, 'b': 3200}));
    final result = filter.filter(
      request: _request(destinationId: 'a'),
      catalog: catalog([
        _province('a', november: SeasonRating.avoid),
        _province('b'),
      ]),
    );

    expect(ids(result), ['a']);
    expect(result.single.minimumCost, 9000);
  });
}
