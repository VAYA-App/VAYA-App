import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/geo.dart';

void main() {
  test('one degree of longitude at the equator is about 111 km', () {
    expect(
      haversineKm(const GeoPoint(0, 0), const GeoPoint(0, 1)),
      closeTo(111.19, 0.01),
    );
  });

  test('travel is zero for the same point', () {
    const p = GeoPoint(13, 100);
    expect(travelBetween(p, p), (km: 0.0, minutes: 0));
  });

  test('short trips use city speed and stretch the distance by 1.3', () {
    // ~7.78 km straight → ~10.1 km by road → 25 km/h.
    final t = travelBetween(
      const GeoPoint(13, 100),
      const GeoPoint(13, 100.072),
    );
    expect(t.km, closeTo(10.1, 0.1));
    expect(t.minutes, (t.km / 25 * 60).ceil());
  });

  test('long trips use highway speed', () {
    final t = travelBetween(
      const GeoPoint(13.7563, 100.5018),
      const GeoPoint(13.0827, 100.9192),
    );
    expect(t.km, greaterThan(15));
    expect(t.minutes, (t.km / 50 * 60).ceil());
  });
}
