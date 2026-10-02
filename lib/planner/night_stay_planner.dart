import '../domain/domain.dart';
import 'geo.dart';

/// Picks one Accommodation for the whole trip (multi-hotel trips are out of
/// scope this round; see docs/SPRINT-2W.md).
class NightStayPlanner {
  const NightStayPlanner();

  /// One [NightStay] per night at the Accommodation of [tier] closest to the
  /// centre of [attractions]. Without one in that tier it steps down a
  /// level at a time, then up. Costs are left at 0 for the cost calculator.
  ///
  /// [fallbackCenter] is used when there are no attractions (e.g. the
  /// province centre).
  List<NightStay> plan({
    required int nights,
    required int travellerCount,
    required int tier,
    required List<Place> attractions,
    required List<Place> accommodations,
    required GeoPoint fallbackCenter,
  }) {
    if (nights <= 0 || accommodations.isEmpty) return const [];
    final hotel = pickAccommodation(
      tier: tier,
      near: centroid(attractions) ?? fallbackCenter,
      accommodations: accommodations,
    );
    final rooms = (travellerCount / 2).ceil();
    return [
      for (var night = 1; night <= nights; night++)
        NightStay(night: night, placeId: hotel.id, rooms: rooms, cost: 0),
    ];
  }

  /// The closest Accommodation in the nearest available tier: [tier] first,
  /// then cheaper tiers, then pricier ones.
  Place pickAccommodation({
    required int tier,
    required GeoPoint near,
    required List<Place> accommodations,
  }) {
    final tiers = [
      for (var t = tier; t >= 1; t--) t,
      for (var t = tier + 1; t <= 4; t++) t,
    ];
    for (final t in tiers) {
      final inTier = accommodations.where((p) => p.priceLevel == t).toList();
      if (inTier.isEmpty) continue;
      inTier.sort(
        (a, b) => haversineKm(
          near,
          a.location,
        ).compareTo(haversineKm(near, b.location)),
      );
      return inTier.first;
    }
    throw ArgumentError.value(accommodations, 'accommodations', 'is empty');
  }

  /// Average position of [places], or `null` when there are none.
  static GeoPoint? centroid(List<Place> places) {
    if (places.isEmpty) return null;
    final lat = places.fold<double>(0, (s, p) => s + p.location.lat);
    final lng = places.fold<double>(0, (s, p) => s + p.location.lng);
    return GeoPoint(lat / places.length, lng / places.length);
  }
}
