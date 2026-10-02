/// A WGS84 coordinate. Kept free of Flutter and Firestore types so the
/// planner stays pure Dart.
final class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  factory GeoPoint.fromJson(Map<String, Object?> json) => GeoPoint(
    (json['lat'] as num).toDouble(),
    (json['lng'] as num).toDouble(),
  );

  final double lat;
  final double lng;

  Map<String, Object?> toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}
