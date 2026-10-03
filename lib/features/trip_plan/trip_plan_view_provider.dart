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

/// A Trip Plan generated in this session that has not been saved yet.
final class DraftTrip {
  const DraftTrip({required this.plan, required this.request});

  final TripPlan plan;
  final TripRequest request;
}

/// Generated plans kept in memory under a temporary trip id until they are
/// saved (#43).
final draftTripsProvider =
    NotifierProvider<DraftTripsNotifier, Map<String, DraftTrip>>(
      DraftTripsNotifier.new,
    );

class DraftTripsNotifier extends Notifier<Map<String, DraftTrip>> {
  var _lastId = 0;

  @override
  Map<String, DraftTrip> build() => const {};

  /// Keeps [plan] and returns the trip id that opens it.
  String add(TripPlan plan, TripRequest request) {
    final id = 'draft-${++_lastId}';
    state = {...state, id: DraftTrip(plan: plan, request: request)};
    return id;
  }
}

/// The mock plan or a draft from [draftTripsProvider]; saved trips are
/// opened by id in #43.
final tripPlanViewProvider = FutureProvider.family<TripPlanView?, String>((
  ref,
  tripId,
) async {
  final TripPlan plan;
  final TripRequest request;
  if (tripId == mockTripId) {
    plan = await ref.watch(mockTripPlanProvider.future);
    request = await ref.watch(mockTripRequestProvider.future);
  } else if (ref.watch(draftTripsProvider.select((d) => d[tripId]))
      case final draft?) {
    plan = draft.plan;
    request = draft.request;
  } else {
    return null;
  }
  return TripPlanView(
    plan: plan,
    request: request,
    catalog: await ref.watch(placeCatalogProvider.future),
  );
});
