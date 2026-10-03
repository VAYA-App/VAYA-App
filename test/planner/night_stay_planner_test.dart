import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/night_stay_planner.dart';

Place place(
  String id,
  double lng, {
  PlaceCategory category = PlaceCategory.accommodation,
  int level = 2,
}) => Place(
  id: id,
  provinceId: 'test',
  category: category,
  name: id,
  location: GeoPoint(13, lng),
  tags: const [],
  priceLevel: level,
  shortDescription: id,
);

void main() {
  const planner = NightStayPlanner();
  final sights = [
    place('s1', 100.10, category: PlaceCategory.attraction),
    place('s2', 100.20, category: PlaceCategory.attraction),
  ];
  const center = GeoPoint(13, 100);

  List<NightStay> plan(
    List<Place> hotels, {
    int tier = 2,
    int nights = 2,
    int people = 2,
    List<Place>? attractions,
  }) => planner.plan(
    nights: nights,
    travellerCount: people,
    tier: tier,
    attractions: attractions ?? sights,
    accommodations: hotels,
    fallbackCenter: center,
  );

  test('picks the hotel in the tier closest to the centre of the sights', () {
    final stays = plan([
      place('far', 100.40),
      place('near', 100.16),
      place('cheap-nearest', 100.15, level: 1),
    ]);

    expect(stays.map((s) => s.placeId), ['near', 'near']);
    expect(stays.map((s) => s.night), [1, 2]);
    expect(stays.every((s) => s.cost == 0), isTrue);
  });

  test('steps down a tier, then up, when the tier has no hotel', () {
    expect(
      plan([
        place('lux', 100.15, level: 4),
        place('budget', 100.5, level: 1),
      ], tier: 3).first.placeId,
      'budget',
    );
    expect(
      plan([place('lux', 100.15, level: 4)], tier: 2).first.placeId,
      'lux',
    );
  });

  test('books one room per two travellers', () {
    expect(plan([place('h', 100.15)], people: 1).first.rooms, 1);
    expect(plan([place('h', 100.15)], people: 3).first.rooms, 2);
    expect(plan([place('h', 100.15)], people: 4).first.rooms, 2);
  });

  test('a day trip has no night stay', () {
    expect(plan([place('h', 100.15)], nights: 0), isEmpty);
  });

  test('uses the fallback centre without attractions', () {
    final stays = plan([
      place('west', 99.95),
      place('east', 100.3),
    ], attractions: const []);
    expect(stays.first.placeId, 'west');
  });

  test('centroid averages positions', () {
    expect(
      NightStayPlanner.centroid(sights),
      const GeoPoint(13, 100.15000000000001),
    );
    expect(NightStayPlanner.centroid(const []), isNull);
  });
}
