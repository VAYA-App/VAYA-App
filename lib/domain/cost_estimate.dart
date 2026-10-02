import 'enums.dart';

/// Cost Estimate of a Trip Plan in baht, split by category (PROJECT-PLAN §9).
/// Always computed by code, never by Gemini (ADR-0001).
final class CostEstimate {
  const CostEstimate({
    required this.intercity,
    required this.accommodation,
    required this.food,
    required this.entrance,
    required this.localTransport,
    required this.buffer,
    required this.total,
    required this.perPerson,
    required this.budget,
  });

  /// Placeholder for a draft plan that has not been priced yet.
  const CostEstimate.unpriced(this.budget)
    : intercity = 0,
      accommodation = 0,
      food = 0,
      entrance = 0,
      localTransport = 0,
      buffer = 0,
      total = 0,
      perPerson = 0;

  factory CostEstimate.fromJson(Map<String, Object?> json) {
    int read(String key) => (json[key] as num).toInt();
    return CostEstimate(
      intercity: read('intercity'),
      accommodation: read('accommodation'),
      food: read('food'),
      entrance: read('entrance'),
      localTransport: read('localTransport'),
      buffer: read('buffer'),
      total: read('total'),
      perPerson: read('perPerson'),
      budget: read('budget'),
    );
  }

  final int intercity;
  final int accommodation;
  final int food;
  final int entrance;
  final int localTransport;

  /// 10% contingency on top of every other category.
  final int buffer;
  final int total;
  final int perPerson;
  final int budget;

  bool get isOverBudget => total > budget;
  int get overBy => isOverBudget ? total - budget : 0;

  Map<String, Object?> toJson() => {
    'intercity': intercity,
    'accommodation': accommodation,
    'food': food,
    'entrance': entrance,
    'localTransport': localTransport,
    'buffer': buffer,
    'total': total,
    'perPerson': perPerson,
    'budget': budget,
  };
}

/// One way to save money on an Over Budget plan (M6).
final class BudgetAdvice {
  const BudgetAdvice({
    required this.kind,
    required this.saving,
    required this.description,
  });

  factory BudgetAdvice.fromJson(Map<String, Object?> json) => BudgetAdvice(
    kind: BudgetAdviceKind.values.byName(json['kind'] as String),
    saving: (json['saving'] as num).toInt(),
    description: json['description'] as String,
  );

  final BudgetAdviceKind kind;

  /// Baht saved on the total if the user follows this advice.
  final int saving;

  /// Thai text shown to the user.
  final String description;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'saving': saving,
    'description': description,
  };
}
