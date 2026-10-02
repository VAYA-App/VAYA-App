import '../domain/domain.dart';

/// Saved trips of the signed-in user at Firestore `trips/{id}`.
/// Implemented in #41.
abstract interface class TripRepository {
  /// The user's trips, most recently updated first.
  Stream<List<Trip>> watchMyTrips();

  Future<Trip?> getTrip(String id);

  /// Creates the trip when [Trip.id] is `null`, otherwise overwrites it.
  /// Returns the trip with its id set.
  Future<Trip> saveTrip(Trip trip);

  Future<void> deleteTrip(String id);
}
