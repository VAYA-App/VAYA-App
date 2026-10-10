import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/asset_place_catalog.dart';
import '../../data/asset_pricing_table.dart';
import '../../data/auth_repository.dart';
import '../../data/mock/in_memory_trip_repository.dart';
import '../../data/mock/mock_auth_repository.dart';
import '../../data/trip_repository.dart';
import '../../domain/domain.dart';
import '../../planner/pricing_table.dart';

final placeCatalogProvider = FutureProvider<PlaceCatalog>(
  (ref) => loadPlaceCatalog(rootBundle),
);

final pricingTableProvider = FutureProvider<PricingTable>(
  (ref) => loadPricingTable(rootBundle),
);

/// Mock for now; the Firebase implementation is deferred (#14).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = MockAuthRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Mock for now; the Firestore implementation is deferred (#41).
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final repository = InMemoryTripRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Real-time stream of the current user's saved trips (#42).
final savedTripsProvider = StreamProvider<List<Trip>>((ref) {
  return ref.watch(tripRepositoryProvider).watchMyTrips();
});
