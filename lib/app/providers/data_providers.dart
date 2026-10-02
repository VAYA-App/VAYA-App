import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/asset_place_catalog.dart';
import '../../data/auth_repository.dart';
import '../../data/trip_repository.dart';
import '../../domain/domain.dart';

final placeCatalogProvider = FutureProvider<PlaceCatalog>(
  (ref) => loadPlaceCatalog(rootBundle),
);

/// Replace the body with the Firebase implementation in #14.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('AuthRepository: see #14'),
);

/// Replace the body with the Firestore implementation in #41.
final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => throw UnimplementedError('TripRepository: see #41'),
);
