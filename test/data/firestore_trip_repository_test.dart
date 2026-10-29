import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/data/firestore_trip_repository.dart';
import 'package:vaya_app/domain/domain.dart';

import '../planner/test_data.dart';

Trip _trip({String? id, String ownerUid = 'u1', int budget = 6000}) {
  final plan = TripPlan.fromJson(
    readJson('assets/mock/trip_plan_chonburi_2d.json'),
  );
  return Trip(
    id: id,
    ownerUid: ownerUid,
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 1),
    request: demoRequest(budget: budget),
    plan: plan,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late String? uid;
  late FirestoreTripRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    uid = 'u1';
    repo = FirestoreTripRepository(currentUid: () => uid, firestore: firestore);
  });

  test(
    'saves a new trip at trips/{id}, reads it back and deletes it',
    () async {
      final saved = await repo.saveTrip(_trip());

      expect(saved.id, isNotNull);
      final doc = await firestore.collection('trips').doc(saved.id).get();
      expect(doc.data()?['ownerUid'], 'u1');
      expect(doc.data()?['createdAt'], '2026-11-01T00:00:00.000Z');

      final read = await repo.getTrip(saved.id!);
      expect(read?.plan.destinationId, 'chonburi');
      expect(read?.plan.cost.total, saved.plan.cost.total);
      expect(read?.request.budget, saved.request.budget);

      await repo.deleteTrip(saved.id!);
      expect(await repo.getTrip(saved.id!), isNull);
    },
  );

  test('saving an existing id overwrites it', () async {
    final saved = await repo.saveTrip(_trip());
    await repo.saveTrip(_trip(id: saved.id, budget: 9000));

    final trips = await repo.watchMyTrips().first;
    expect(trips, hasLength(1));
    expect(trips.single.request.budget, 9000);
  });

  test('lists the most recently updated first and follows changes', () async {
    final updates = <List<String?>>[];
    final sub = repo.watchMyTrips().listen(
      (trips) => updates.add([for (final t in trips) t.id]),
    );
    await pumpEventQueue();
    final first = await repo.saveTrip(_trip(id: 'a'));
    await pumpEventQueue();
    final second = await repo.saveTrip(_trip(id: 'b'));
    await pumpEventQueue();
    await repo.deleteTrip(first.id!);
    await pumpEventQueue();
    await sub.cancel();

    expect(updates, [
      <String>[],
      [first.id],
      [second.id, first.id],
      [second.id],
    ]);
  });

  test('lists only the signed-in user\'s trips', () async {
    await repo.saveTrip(_trip(id: 'mine'));
    await repo.saveTrip(_trip(id: 'theirs', ownerUid: 'u2'));

    expect((await repo.watchMyTrips().first).map((t) => t.id), ['mine']);

    uid = null;
    expect(await repo.watchMyTrips().first, isEmpty);
  });

  test('a document that no longer parses is skipped, not lost', () async {
    await firestore.collection('trips').doc('broken').set({'ownerUid': 'u1'});
    await repo.saveTrip(_trip(id: 'ok'));

    expect((await repo.watchMyTrips().first).map((t) => t.id), ['ok']);
    expect(await repo.getTrip('broken'), isNull);
    final doc = await firestore.collection('trips').doc('broken').get();
    expect(doc.exists, isTrue);
  });
}
