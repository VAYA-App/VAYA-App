import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../../data/asset_place_catalog.dart';
import '../../data/asset_pricing_table.dart';
import '../../data/auth_repository.dart';
import '../../data/firebase_auth_repository.dart';
import '../../data/mock/in_memory_trip_repository.dart';
import '../../data/mock/mock_auth_repository.dart';
import '../../data/photo_catalog.dart';
import '../../data/trip_repository.dart';
import '../../domain/domain.dart';
import '../../planner/pricing_table.dart';
import '../../planner/taste_profile.dart';

final placeCatalogProvider = FutureProvider<PlaceCatalog>(
  (ref) => loadPlaceCatalog(rootBundle),
);

/// Credits of the bundled Place and Destination photos (ADR-0006).
final photoCatalogProvider = FutureProvider<PhotoCatalog>(
  (ref) => loadPhotoCatalog(rootBundle),
);

final pricingTableProvider = FutureProvider<PricingTable>(
  (ref) => loadPricingTable(rootBundle),
);

/// Firebase Auth where `main.dart` started Firebase (Android, #14); the mock
/// everywhere else (web, iOS and tests) until those apps are registered.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Firebase.apps.isNotEmpty) return FirebaseAuthRepository();
  final repository = MockAuthRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// In memory by default, for tests; `main.dart` overrides it with the
/// local Hive database (#142). Firestore is deferred (#41).
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final repository = InMemoryTripRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Real-time stream of the current user's saved trips (#42).
final _authStateChangesProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
final savedTripsProvider = StreamProvider<List<Trip>>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final user = ref.watch(_authStateChangesProvider).value ?? auth.currentUser;
  if (user == null) return Stream.value(const []);
  return ref
      .watch(tripRepositoryProvider)
      .watchMyTrips()
      .map(
        (trips) => [
          for (final trip in trips)
            if (trip.ownerUid == user.uid) trip,
        ],
      );
});

/// Where Place Feedback is kept: place id → `like` / `dislike`. `main.dart`
/// overrides it with a Hive box; `null` keeps feedback in memory (#49).
final placeFeedbackBoxProvider = Provider<Box<String>?>((ref) => null);

/// The traveller's Taste Profile from 👍/👎 on Stops (#49).
final tasteProfileProvider =
    NotifierProvider<TasteProfileNotifier, TasteProfile>(
      TasteProfileNotifier.new,
    );

class TasteProfileNotifier extends Notifier<TasteProfile> {
  static const boxName = 'place_feedback';

  @override
  TasteProfile build() {
    final box = ref.watch(placeFeedbackBoxProvider);
    if (box == null) return const TasteProfile();
    final byName = PlaceFeedback.values.asNameMap();
    return TasteProfile({
      for (final key in box.keys) key as String: ?byName[box.get(key)],
    });
  }

  /// Sets or, with `null`, clears the feedback on [placeId]. The state
  /// changes at once; the future completes when it is on disk.
  Future<void> set(String placeId, PlaceFeedback? feedback) async {
    state = state.withFeedback(placeId, feedback);
    final box = ref.read(placeFeedbackBoxProvider);
    if (feedback == null) {
      await box?.delete(placeId);
    } else {
      await box?.put(placeId, feedback.name);
    }
  }

  Future<void> clear() async {
    state = const TasteProfile();
    await ref.read(placeFeedbackBoxProvider)?.clear();
  }
}
