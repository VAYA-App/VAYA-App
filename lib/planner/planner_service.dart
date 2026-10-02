import '../domain/domain.dart';

/// Builds a Trip Plan for one Destination (pipeline ⑤–⑩). Implemented in #31.
abstract interface class PlannerService {
  /// Emits progress for the generating screen and ends with a
  /// [PlanningStage.done] event that carries the plan.
  Stream<PlanningProgress> generate({
    required TripRequest request,
    required String destinationId,
  });
}

enum PlanningStage {
  selectingPlaces('กำลังเลือกที่เที่ยว…'),
  validating('กำลังตรวจสอบแผน…'),
  orderingRoutes('กำลังจัดเส้นทาง…'),
  pricing('กำลังคำนวณค่าใช้จ่าย…'),
  done('เสร็จแล้ว');

  const PlanningStage(this.message);
  final String message;
}

final class PlanningProgress {
  const PlanningProgress(this.stage, {this.plan})
    : assert(stage != PlanningStage.done || plan != null);

  final PlanningStage stage;

  /// Set only when [stage] is [PlanningStage.done].
  final TripPlan? plan;
}
