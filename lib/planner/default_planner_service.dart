import '../domain/domain.dart';
import 'candidate_builder.dart';
import 'cost_calculator.dart';
import 'night_stay_planner.dart';
import 'over_budget_advisor.dart';
import 'plan_editor.dart';
import 'place_selector.dart';
import 'planner_service.dart';
import 'route_orderer.dart';
import 'slot_template.dart';

/// The real planning pipeline ⑤–⑩ (PROJECT-PLAN §8):
/// candidates → Gemini selection (validated, with fallback) → night stay →
/// route and times → cost → over-budget advice.
class DefaultPlannerService implements PlannerService {
  const DefaultPlannerService({
    required this.loadCatalog,
    required this.selector,
    required this.costCalculator,
    required this.overBudgetAdvisor,
    this.candidateBuilder = const CandidateBuilder(),
    this.nightStayPlanner = const NightStayPlanner(),
    this.routeOrderer = const RouteOrderer(),
  });

  final Future<PlaceCatalog> Function() loadCatalog;
  final PlaceSelector selector;
  final CostCalculator costCalculator;
  final OverBudgetAdvisor overBudgetAdvisor;
  final CandidateBuilder candidateBuilder;
  final NightStayPlanner nightStayPlanner;
  final RouteOrderer routeOrderer;

  @override
  Stream<PlanningProgress> generate({
    required TripRequest request,
    required String destinationId,
  }) async* {
    yield const PlanningProgress(PlanningStage.selectingPlaces);
    final catalog = await loadCatalog();
    final province = catalog.province(destinationId);
    final intercity = _intercity(request, province);
    final days = SlotTemplate.forTrip(
      request,
      intercityMinutes: intercity?.option.durationMin,
    );
    final candidates = candidateBuilder.build(
      request: request,
      provinceId: destinationId,
      catalog: catalog,
    );
    final (:selection, source: _) = await selector.select(
      request: request,
      province: province,
      days: days,
      candidates: candidates,
    );

    // Validation and the Gemini retry happen inside the selector.
    yield const PlanningProgress(PlanningStage.validating);

    yield const PlanningProgress(PlanningStage.orderingRoutes);
    final attractions = [
      for (final day in selection.days)
        for (final pick in day)
          if (!pick.slot.isMeal) catalog.place(pick.placeId),
    ];
    final nightStays = nightStayPlanner.plan(
      nights: request.nightCount,
      travellerCount: request.travellerCount,
      tier: selection.accommodationTier,
      attractions: attractions,
      accommodations: candidates.accommodations,
      fallbackCenter: province.center,
    );
    yield const PlanningProgress(PlanningStage.pricing);
    final plan =
        PlanEditor(
          costCalculator: costCalculator,
          overBudgetAdvisor: overBudgetAdvisor,
          routeOrderer: routeOrderer,
        ).assemble(
          request: request,
          catalog: catalog,
          destinationId: destinationId,
          intercity: intercity == null
              ? null
              : IntercityLeg(
                  mode: intercity.mode,
                  durationMin: intercity.option.durationMin,
                  cost: 0,
                ),
          nightStays: nightStays,
          picks: selection.days,
        );

    yield PlanningProgress(PlanningStage.done, plan: plan);
  }

  /// The way to reach [province], or `null` when the trip stays in the
  /// Origin (or there is no fare data for the route). When the route lacks
  /// the chosen mode, the first mode it has is used and the leg says so.
  ({IntercityMode mode, IntercityOption option})? _intercity(
    TripRequest request,
    Province province,
  ) {
    if (request.staysInOrigin(province.id)) return null;
    final options = province.intercity[request.originId];
    if (options == null || options.isEmpty) return null;
    final chosen = request.intercityMode ?? IntercityMode.bus;
    if (options[chosen] case final option?) {
      return (mode: chosen, option: option);
    }
    final MapEntry(key: mode, value: option) = options.entries.first;
    return (mode: mode, option: option);
  }
}
