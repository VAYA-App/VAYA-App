import '../domain/domain.dart';

/// Suggests how to bring an Over Budget plan under budget. Implemented in #37.
abstract interface class OverBudgetAdvisor {
  /// The 2–3 options that save the most, largest saving first.
  /// Empty when [plan] is within budget.
  List<BudgetAdvice> advise({
    required TripRequest request,
    required TripPlan plan,
    required PlaceCatalog catalog,
  });
}
