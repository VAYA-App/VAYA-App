import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/data_providers.dart';
import '../../app/providers/mock_providers.dart';
import '../../app/providers/planner_providers.dart';
import '../../domain/domain.dart';
import '../../planner/default_over_budget_advisor.dart';

/// Id that opens the bundled mock plan (`assets/mock/`).
const mockTripId = 'mock';

/// Id that opens the mock plan priced for a budget it cannot meet, to
/// preview the Over Budget screen before the real pipeline (#31) is used.
const mockOverBudgetTripId = 'mock-over-budget';

/// Everything the trip plan screen shows for one trip.
final class TripPlanView {
  const TripPlanView({
    required this.plan,
    required this.request,
    required this.catalog,
    this.savedTrip,
  });

  final TripPlan plan;
  final TripRequest request;
  final PlaceCatalog catalog;

  /// The saved trip this plan was opened from; `null` for drafts and mocks,
  /// which can still be saved (#43).
  final Trip? savedTrip;

  bool get isSaved => savedTrip != null;

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

/// The mock plan, a draft from [draftTripsProvider], or a trip saved in
/// the trip repository (#43).
final tripPlanViewProvider = FutureProvider.family<TripPlanView?, String>((
  ref,
  tripId,
) async {
  // Watched before any await so the dependency is registered up front.
  final catalog = ref.watch(placeCatalogProvider.future);
  final TripPlan plan;
  final TripRequest request;
  Trip? saved;
  if (tripId == mockTripId) {
    plan = await ref.watch(mockTripPlanProvider.future);
    request = await ref.watch(mockTripRequestProvider.future);
  } else if (tripId == mockOverBudgetTripId) {
    final mock = await ref.watch(mockTripRequestProvider.future);
    request = mock.copyWith(
      budget: 1500,
      localTransportMode: LocalTransportMode.taxi,
    );
    final catalog = await ref.watch(placeCatalogProvider.future);
    final calculator = await ref.watch(costCalculatorProvider.future);
    final advisor = await ref.watch(overBudgetAdvisorProvider.future);
    final priced = calculator.applyCosts(
      request: request,
      plan: await ref.watch(mockTripPlanProvider.future),
      catalog: catalog,
    );
    plan = priced.copyWith(
      overBudgetAdvice: advisor.advise(
        request: request,
        plan: priced,
        catalog: catalog,
      ),
    );
  } else if (ref.watch(draftTripsProvider.select((d) => d[tripId]))
      case final draft?) {
    plan = draft.plan;
    request = draft.request;
  } else if (await ref.watch(tripRepositoryProvider).getTrip(tripId)
      case final trip?) {
    saved = trip;
    plan = trip.plan;
    request = trip.request;
  } else {
    return null;
  }
  return TripPlanView(
    plan: plan,
    request: request,
    catalog: await catalog,
    savedTrip: saved,
  );
});

/// What it takes to afford the trip when the advice on its plan is not
/// enough; `null` when the plan fits its budget or the advice gets it there.
final budgetRescueProvider = FutureProvider.family<BudgetRescue?, String>((
  ref,
  tripId,
) async {
  final view = await ref.watch(tripPlanViewProvider(tripId).future);
  if (view == null || !view.plan.cost.isOverBudget) return null;
  final advisor = await ref.watch(budgetRescuerProvider.future);
  return advisor.rescue(
    request: view.request,
    plan: view.plan,
    catalog: view.catalog,
  );
});
