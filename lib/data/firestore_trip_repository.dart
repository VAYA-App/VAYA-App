import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/domain.dart';
import 'trip_repository.dart';

/// Saved trips in Cloud Firestore at `trips/{tripId}` (#41). Each document
/// is `Trip.toJson()`; `firestore.rules` lets only the user in `ownerUid`
/// read or change it, so every query filters on the signed-in user.
class FirestoreTripRepository implements TripRepository {
  FirestoreTripRepository({
    required this.currentUid,
    FirebaseFirestore? firestore,
  }) : _trips = (firestore ?? FirebaseFirestore.instance).collection('trips');

  /// The signed-in user, read each time the trips are listed.
  final String? Function() currentUid;
  final CollectionReference<Map<String, Object?>> _trips;

  /// An entry that no longer parses is skipped, like in the Hive repository,
  /// so one bad document never hides the others.
  static Trip? _read(DocumentSnapshot<Map<String, Object?>> doc) {
    final json = doc.data();
    if (json == null) return null;
    try {
      return Trip.fromJson(doc.id, json);
    } on Object {
      return null;
    }
  }

  /// Sorted here rather than with `orderBy`, so the query needs no
  /// composite index in the Firebase project.
  @override
  Stream<List<Trip>> watchMyTrips() {
    final uid = currentUid();
    if (uid == null) return Stream.value(const []);
    return _trips
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) =>
              [for (final doc in snapshot.docs) ?_read(doc)]
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
        );
  }

  /// The rules refuse to read a trip that is missing or belongs to someone
  /// else; both mean there is no trip to show.
  @override
  Future<Trip?> getTrip(String id) async {
    try {
      return _read(await _trips.doc(id).get());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  @override
  Future<Trip> saveTrip(Trip trip) async {
    final doc = trip.id == null ? _trips.doc() : _trips.doc(trip.id);
    final saved = trip.copyWith(id: doc.id, updatedAt: DateTime.now());
    await doc.set(saved.toJson());
    return saved;
  }

  @override
  Future<void> deleteTrip(String id) => _trips.doc(id).delete();
}
