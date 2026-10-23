import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:vaya_app/data/hive_trip_repository.dart';
import 'package:vaya_app/domain/domain.dart';

import '../planner/test_data.dart';

Trip _trip({String? id, int budget = 6000}) {
  final plan = TripPlan.fromJson(
    readJson('assets/mock/trip_plan_chonburi_2d.json'),
  );
  return Trip(
    id: id,
    ownerUid: 'u1',
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 1),
    request: demoRequest(budget: budget),
    plan: plan,
  );
}

void main() {
  late Directory dir;
  late HiveTripRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vaya_hive_');
    Hive.init(dir.path);
    repo = await HiveTripRepository.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('saving gives a new trip an id and reads it back', () async {
    final saved = await repo.saveTrip(_trip());

    expect(saved.id, isNotNull);
    final read = await repo.getTrip(saved.id!);
    expect(read?.plan.destinationId, 'chonburi');
    expect(read?.plan.cost.total, saved.plan.cost.total);
    expect(read?.request.budget, saved.request.budget);
  });

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
    final second = await repo.saveTrip(_trip(id: 'b'));
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

  test('trips are still there after the box is reopened', () async {
    final saved = await repo.saveTrip(_trip());
    await Hive.close();

    final reopened = await HiveTripRepository.open();
    expect((await reopened.getTrip(saved.id!))?.ownerUid, 'u1');
  });

  test('an entry that no longer parses is skipped, not lost', () async {
    final box = Hive.box<String>(HiveTripRepository.boxName);
    await box.put('broken', '{not json');
    await repo.saveTrip(_trip(id: 'ok'));

    expect((await repo.watchMyTrips().first).map((t) => t.id), ['ok']);
    expect(await repo.getTrip('broken'), isNull);
    expect(box.get('broken'), '{not json');
  });
}
