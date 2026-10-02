import '../domain/domain.dart';

/// Deterministic pricing from `assets/data/pricing.json` (PROJECT-PLAN §9).
/// Implemented in #34 and #35.
abstract interface class CostCalculator {
  /// Returns [plan] with the cost of every Stop, Night Stay and the
  /// Intercity leg filled in, plus [TripPlan.cost] and [TripPlan.status].
  /// A trip that stays in its Origin province has no intercity cost.
  TripPlan applyCosts({
    required TripRequest request,
    required TripPlan plan,
    required PlaceCatalog catalog,
  });

  /// Cheapest possible total for [request] in [province]; used to filter
  /// provinces before ranking them (#24).
  int minimumTripCost({
    required TripRequest request,
    required Province province,
  });
}
