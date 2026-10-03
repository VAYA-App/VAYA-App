import 'dart:math' as math;

import '../domain/domain.dart';

/// Straight-line distances are stretched by this factor to approximate
/// winding roads (PROJECT-PLAN §10).
const roadFactor = 1.3;

/// Trips longer than this leave the city and drive faster.
const _cityLimitKm = 15.0;
const _citySpeedKmh = 25.0;
const _highwaySpeedKmh = 50.0;

const _earthRadiusKm = 6371.0;

/// Great-circle distance between [a] and [b] in kilometres.
double haversineKm(GeoPoint a, GeoPoint b) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
}

/// Estimated road distance (one decimal) and travel time (whole minutes,
/// rounded up) between two points.
({double km, int minutes}) travelBetween(GeoPoint from, GeoPoint to) {
  final km = (haversineKm(from, to) * roadFactor * 10).round() / 10;
  if (km == 0) return (km: 0, minutes: 0);
  final speed = km > _cityLimitKm ? _highwaySpeedKmh : _citySpeedKmh;
  return (km: km, minutes: (km / speed * 60).ceil());
}
