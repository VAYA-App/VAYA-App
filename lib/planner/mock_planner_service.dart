import '../domain/domain.dart';
import 'planner_service.dart';

/// Stand-in for the real pipeline (#31): reports each stage after a short
/// pause, then returns a ready-made plan. Lets the whole flow from the
/// form to the plan screen run before the planner exists.
class MockPlannerService implements PlannerService {
  const MockPlannerService({
    required this.loadPlan,
    this.stepDelay = const Duration(milliseconds: 700),
  });

  final Future<TripPlan> Function() loadPlan;
  final Duration stepDelay;

  @override
  Stream<PlanningProgress> generate({
    required TripRequest request,
    required String destinationId,
  }) async* {
    for (final stage in PlanningStage.values) {
      if (stage == PlanningStage.done) break;
      yield PlanningProgress(stage);
      await Future<void>.delayed(stepDelay);
    }
    yield PlanningProgress(PlanningStage.done, plan: await loadPlan());
  }
}
