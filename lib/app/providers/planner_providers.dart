import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/cost_calculator.dart';
import '../../planner/default_cost_calculator.dart';
import '../../planner/default_over_budget_advisor.dart';
import '../../planner/default_planner_service.dart';
import '../../planner/destination_suggester.dart';
import '../../planner/mock_planner_service.dart';
import '../../planner/over_budget_advisor.dart';
import '../../planner/place_selector.dart';
import '../../planner/planner_service.dart';
import 'ai_providers.dart';
import 'data_providers.dart';
import 'mock_providers.dart';

/// Asynchronous because the pricing table is a bundled asset.
final costCalculatorProvider = FutureProvider<CostCalculator>(
  (ref) async =>
      DefaultCostCalculator(await ref.watch(pricingTableProvider.future)),
);

/// Prices its options with [costCalculatorProvider], so it is a future too.
final overBudgetAdvisorProvider = FutureProvider<OverBudgetAdvisor>(
  (ref) async =>
      DefaultOverBudgetAdvisor(await ref.watch(costCalculatorProvider.future)),
);

/// Replace the body with the real implementation in #25.
final destinationSuggesterProvider = Provider<DestinationSuggester>(
  (ref) => throw UnimplementedError('DestinationSuggester: see #25'),
);

/// Mock for now: replays the bundled plan. The real pipeline lands in #31.
final plannerServiceProvider = Provider<PlannerService>(
  (ref) =>
      MockPlannerService(loadPlan: () => ref.read(mockTripPlanProvider.future)),
);

/// The real pipeline (#31), ready for [plannerServiceProvider] to point
/// here. It is a future because [costCalculatorProvider] and
/// [overBudgetAdvisorProvider] are.
final pipelinePlannerServiceProvider = FutureProvider<PlannerService>((
  ref,
) async {
  final selector = PlaceSelector(gemini: ref.watch(geminiServiceProvider));
  final costCalculator = ref.watch(costCalculatorProvider.future);
  final overBudgetAdvisor = ref.watch(overBudgetAdvisorProvider.future);
  return DefaultPlannerService(
    loadCatalog: () => ref.read(placeCatalogProvider.future),
    selector: selector,
    costCalculator: await costCalculator,
    overBudgetAdvisor: await overBudgetAdvisor,
  );
});
