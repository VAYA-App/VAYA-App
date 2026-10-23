import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import '../../planner/cost_calculator.dart';
import '../../planner/default_cost_calculator.dart';
import '../../planner/default_over_budget_advisor.dart';
import '../../planner/default_planner_service.dart';
import '../../planner/destination_suggester.dart';
import '../../planner/gemini_destination_suggester.dart';
import '../../planner/over_budget_advisor.dart';
import '../../planner/place_selector.dart';
import '../../planner/plan_editor.dart';
import '../../planner/planner_service.dart';
import 'ai_providers.dart';
import 'data_providers.dart';

/// Asynchronous because the pricing table is a bundled asset.
final costCalculatorProvider = FutureProvider<CostCalculator>(
  (ref) async =>
      DefaultCostCalculator(await ref.watch(pricingTableProvider.future)),
);

/// The advisor as its own type: besides advice it works out the budget a
/// trip needs (`rescue`), which the plan screen shows (#38). It prices with
/// [costCalculatorProvider], so it is a future too.
final budgetRescuerProvider = FutureProvider<DefaultOverBudgetAdvisor>(
  (ref) async =>
      DefaultOverBudgetAdvisor(await ref.watch(costCalculatorProvider.future)),
);

final overBudgetAdvisorProvider = FutureProvider<OverBudgetAdvisor>(
  (ref) => ref.watch(budgetRescuerProvider.future),
);

/// Edits a plan with the same pricing and advice as the pipeline (#45).
final planEditorProvider = FutureProvider<PlanEditor>((ref) async {
  final costCalculator = ref.watch(costCalculatorProvider.future);
  final overBudgetAdvisor = ref.watch(overBudgetAdvisorProvider.future);
  return PlanEditor(
    costCalculator: await costCalculator,
    overBudgetAdvisor: await overBudgetAdvisor,
  );
});

/// Pipeline ②–③ (#24, #25). Without Gemini (#26) it ranks the provinces
/// that fit by their minimum cost.
final destinationSuggesterProvider = Provider<DestinationSuggester>(
  (ref) => GeminiDestinationSuggester(
    gemini: ref.watch(geminiServiceProvider),
    loadCatalog: () => ref.read(placeCatalogProvider.future),
    loadCostCalculator: () => ref.read(costCalculatorProvider.future),
  ),
);

/// The planner the app uses: the real pipeline (#31). Not a future itself,
/// so screens and test overrides keep a plain [PlannerService].
final plannerServiceProvider = Provider<PlannerService>(
  (ref) => _PendingPlannerService(
    () => ref.read(pipelinePlannerServiceProvider.future),
  ),
);

/// The real pipeline. It is a future because [costCalculatorProvider] and
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

/// Waits for [load] on each run, then replays that planner's progress.
class _PendingPlannerService implements PlannerService {
  const _PendingPlannerService(this.load);

  final Future<PlannerService> Function() load;

  @override
  Stream<PlanningProgress> generate({
    required TripRequest request,
    required String destinationId,
  }) async* {
    final planner = await load();
    yield* planner.generate(request: request, destinationId: destinationId);
  }
}
