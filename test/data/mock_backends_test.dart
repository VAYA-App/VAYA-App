import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/ai/gemini_service.dart';
import 'package:vaya_app/ai/mock_gemini_service.dart';
import 'package:vaya_app/data/mock/in_memory_trip_repository.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/domain/domain.dart';

Map<String, Object?> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

Trip mockTrip({String? id}) => Trip(
  id: id,
  ownerUid: MockAuthRepository.demoUser.uid,
  createdAt: DateTime(2026, 10, 5),
  updatedAt: DateTime(2026, 10, 5),
  request: TripRequest.fromJson(readJson('assets/mock/trip_request_demo.json')),
  plan: TripPlan.fromJson(readJson('assets/mock/trip_plan_chonburi_2d.json')),
);

void main() {
  group('MockAuthRepository', () {
    test('starts signed out, then signs in and out as the demo user', () async {
      final auth = MockAuthRepository(signInDelay: Duration.zero);
      addTearDown(auth.dispose);
      final states = <String>[];
      final sub = auth.authStateChanges().listen(
        (u) => states.add(u == null ? 'out' : u.uid),
      );

      await auth.signInWithGoogle();
      await auth.signOut();
      await pumpEventQueue();
      await sub.cancel();

      expect(states, ['out', 'demo-user', 'out']);
      expect(auth.currentUser, isNull);
    });
  });

  group('InMemoryTripRepository', () {
    test('saves, lists newest first, reads and deletes trips', () async {
      final repo = InMemoryTripRepository();
      addTearDown(repo.dispose);

      final first = await repo.saveTrip(mockTrip());
      final second = await repo.saveTrip(mockTrip());

      expect(first.id, isNotNull);
      expect(second.id, isNot(first.id));
      expect((await repo.watchMyTrips().first).map((t) => t.id), [
        second.id,
        first.id,
      ]);
      expect((await repo.getTrip(first.id!))?.plan.destinationId, 'chonburi');

      await repo.deleteTrip(first.id!);
      expect(await repo.getTrip(first.id!), isNull);
    });

    test('saving a trip with an id overwrites it', () async {
      final repo = InMemoryTripRepository();
      addTearDown(repo.dispose);

      final saved = await repo.saveTrip(mockTrip());
      await repo.saveTrip(saved);

      expect(await repo.watchMyTrips().first, hasLength(1));
    });
  });

  group('MockGeminiService', () {
    const call = (system: 'sys', prompt: 'prompt');

    test('fails by default so callers use their fallback', () {
      expect(
        const MockGeminiService().generateJson(
          systemInstruction: call.system,
          prompt: call.prompt,
          responseSchema: const {},
        ),
        throwsA(isA<GeminiException>()),
      );
    });

    test('returns canned JSON from a responder', () async {
      final gemini = MockGeminiService(responder: (_, _) => {'ok': true});

      expect(
        await gemini.generateJson(
          systemInstruction: call.system,
          prompt: call.prompt,
          responseSchema: const {},
        ),
        {'ok': true},
      );
    });
  });
}
