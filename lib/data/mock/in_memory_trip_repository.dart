import 'dart:async';

import '../../domain/domain.dart';
import '../trip_repository.dart';

/// Keeps trips in memory until Firestore is set up (deferred, see #41).
/// Trips are lost when the app restarts.
class InMemoryTripRepository implements TripRepository {
  final _trips = <String, Trip>{};
  final _changes = StreamController<List<Trip>>.broadcast();
  var _nextId = 1;

  List<Trip> get _sorted =>
      _trips.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Stream<List<Trip>> watchMyTrips() async* {
    yield _sorted;
    yield* _changes.stream;
  }

  @override
  Future<Trip?> getTrip(String id) async => _trips[id];

  @override
  Future<Trip> saveTrip(Trip trip) async {
    final saved = trip.copyWith(
      id: trip.id ?? 'trip-${_nextId++}',
      updatedAt: DateTime.now(),
    );
    _trips[saved.id!] = saved;
    _changes.add(_sorted);
    return saved;
  }

  @override
  Future<void> deleteTrip(String id) async {
    if (_trips.remove(id) != null) _changes.add(_sorted);
  }

  void dispose() => _changes.close();
}
