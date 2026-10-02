import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/data_providers.dart';
import '../../app/providers/mock_providers.dart';
import '../../domain/domain.dart';

/// Id that opens the bundled mock plan (`assets/mock/`).
const mockTripId = 'mock';

/// Everything the trip plan screen shows for one trip.
final class TripPlanView {
  const TripPlanView({
    required this.plan,
    required this.request,
    required this.catalog,
  });

  final TripPlan plan;
  final TripRequest request;
  final PlaceCatalog catalog;

  Province get destination => catalog.province(plan.destinationId);
}

/// Only the mock plan for now; saved trips are opened by id in #43.
final tripPlanViewProvider = FutureProvider.family<TripPlanView?, String>((
  ref,
  tripId,
) async {
  if (tripId != mockTripId) return null;
  return TripPlanView(
    plan: await ref.watch(mockTripPlanProvider.future),
    request: await ref.watch(mockTripRequestProvider.future),
    catalog: await ref.watch(placeCatalogProvider.future),
  );
});
