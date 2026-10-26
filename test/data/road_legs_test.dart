import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/data/road_router.dart';
import 'package:vaya_app/domain/domain.dart';

void main() {
  const a = GeoPoint(13.0, 100.0);
  const b = GeoPoint(13.0, 100.2);
  const c = GeoPoint(13.2, 100.2);

  test('without a road every leg is a straight line', () {
    expect(splitIntoLegs(null, [a, b, c]), [
      [a, b],
      [b, c],
    ]);
  });

  test('cuts the road at the point nearest each waypoint', () {
    final road = [
      a,
      const GeoPoint(13.0, 100.1),
      const GeoPoint(13.0, 100.199), // nearest to b
      const GeoPoint(13.1, 100.2),
      c,
    ];
    final legs = splitIntoLegs(road, [a, b, c]);
    expect(legs, hasLength(2));
    expect(legs[0].first, a);
    expect(legs[0].last, road[2]);
    expect(legs[1].first, road[2]);
    expect(legs[1].last, c);
  });

  test('one waypoint has no legs', () {
    expect(splitIntoLegs([a, b], [a]), isEmpty);
  });
}
