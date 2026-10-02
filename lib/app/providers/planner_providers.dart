import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/cost_calculator.dart';
import '../../planner/default_planner_service.dart';
import '../../planner/destination_suggester.dart';
import '../../planner/mock_planner_service.dart';
import '../../planner/over_budget_advisor.dart';
import '../../planner/place_selector.dart';
import '../../planner/planner_service.dart';
import 'ai_providers.dart';
import 'data_providers.dart';
import 'mock_providers.dart';

/// Replace the body with the real implementation in #34.
final costCalculatorProvider = Provider<CostCalculator>(
  (ref) => throw UnimplementedError('CostCalculator: see #34'),
);

/// Replace the body with the real implementation in #37.
final overBudgetAdvisorProvider = Provider<OverBudgetAdvisor>(
  (ref) => throw UnimplementedError('OverBudgetAdvisor: see #37'),
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

/// The real pipeline (#31). It still needs [costCalculatorProvider] (#34)
/// and [overBudgetAdvisorProvider] (#37); once they land, point
/// [plannerServiceProvider] here.
final pipelinePlannerServiceProvider = Provider<PlannerService>(
  (ref) => DefaultPlannerService(
    loadCatalog: () => ref.read(placeCatalogProvider.future),
    selector: PlaceSelector(gemini: ref.watch(geminiServiceProvider)),
    costCalculator: ref.watch(costCalculatorProvider),
    overBudgetAdvisor: ref.watch(overBudgetAdvisorProvider),
  ),
);
