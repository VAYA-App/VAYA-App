import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../domain/domain.dart';
import 'trip_repository.dart';

/// Saved trips in a local Hive box, so they survive restarts on Android,
/// iOS and the web (#142). Each entry is `Trip.toJson()` as a string under
/// the trip id, the same shape Firestore will store (#41).
class HiveTripRepository implements TripRepository {
  HiveTripRepository(this._box);

  static const boxName = 'trips';

  final Box<String> _box;

  /// Opens the box the app uses; call `Hive.initFlutter()` first.
  static Future<HiveTripRepository> open() async =>
      HiveTripRepository(await Hive.openBox<String>(boxName));

  List<Trip> get _sorted =>
      [for (final key in _box.keys) ?_read(key as String)]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// An entry that no longer parses is skipped, not deleted, so a format
  /// change never loses data silently.
  Trip? _read(String id) {
    final json = _box.get(id);
    if (json == null) return null;
    try {
      return Trip.fromJson(id, jsonDecode(json) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  @override
  Stream<List<Trip>> watchMyTrips() async* {
    yield _sorted;
    yield* _box.watch().map((_) => _sorted);
  }

  @override
  Future<Trip?> getTrip(String id) async => _read(id);

  @override
  Future<Trip> saveTrip(Trip trip) async {
    final saved = trip.copyWith(
      id: trip.id ?? 'trip-${DateTime.now().microsecondsSinceEpoch}',
      updatedAt: DateTime.now(),
    );
    await _box.put(saved.id!, jsonEncode(saved.toJson()));
    return saved;
  }

  @override
  Future<void> deleteTrip(String id) => _box.delete(id);
}
