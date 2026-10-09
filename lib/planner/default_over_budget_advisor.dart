import '../domain/domain.dart';
import 'cost_calculator.dart';
import 'night_stay_planner.dart';
import 'over_budget_advisor.dart';

/// What is left when every option is taken together and the plan is still
/// Over Budget: how much budget the trip needs, and how short it would have
/// to be to fit the one the user has.
final class BudgetRescue {
  const BudgetRescue({
    required this.stillOverBy,
    required this.minimumBudget,
    this.daysThatFit,
    this.costOfDaysThatFit,
  });

  /// Baht above the Budget after every option is applied to one plan.
  final int stillOverBy;

  /// The cheapest this trip can be, rounded up to a hundred baht.
  final int minimumBudget;

  /// The longest trip whose cheapest cost fits the Budget; `null` when not
  /// even one day does.
  final int? daysThatFit;
  final int? costOfDaysThatFit;
}

/// One way to change a plan, ready to be priced again.
typedef _Change = ({TripRequest request, TripPlan plan, String label});

/// Prices every option with [calculator], the same one that priced the
/// plan, so a saving is always the difference between two real totals.
/// Savings are per option and must not be added together.
class DefaultOverBudgetAdvisor implements OverBudgetAdvisor {
  const DefaultOverBudgetAdvisor(
    this.calculator, {
    this.nightStayPlanner = const NightStayPlanner(),
  });

  final CostCalculator calculator;
  final NightStayPlanner nightStayPlanner;

  static const maxAdvice = 3;

  @override
  List<BudgetAdvice> advise({
    required TripRequest request,
    required TripPlan plan,
    required PlaceCatalog catalog,
  }) {
    if (!plan.cost.isOverBudget) return const [];

    final advice = <BudgetAdvice>[];
    void offer(BudgetAdviceKind kind, _Change? change) {
      if (change == null) return;
      final saving = plan.cost.total - _total(change, catalog);
      if (saving <= 0) return;
      advice.add(
        BudgetAdvice(
          kind: kind,
          saving: saving,
          description: '${change.label} ประหยัด ~${_baht(saving)}',
        ),
      );
    }

    offer(
      BudgetAdviceKind.downgradeAccommodation,
      _cheaperStay(request, plan, catalog),
    );
    offer(
      BudgetAdviceKind.changeLocalTransport,
      _cheapestTransport(request, plan, catalog),
    );
    offer(BudgetAdviceKind.removeDay, _shorterTrip(request, plan));
    advice.sort((a, b) => b.saving.compareTo(a.saving));

    // A lower bound, not a priced plan, so it never outranks the others.
    final elsewhere = _cheaperDestination(request, plan, catalog);
    return [...advice, ?elsewhere].take(maxAdvice).toList();
  }

  /// `null` when the plan fits the Budget, or would once every option is
  /// applied to it at the same time.
  BudgetRescue? rescue({
    required TripRequest request,
    required TripPlan plan,
    required PlaceCatalog catalog,
  }) {
    if (!plan.cost.isOverBudget) return null;

    _Change all = (request: request, plan: plan, label: '');
    for (final option in [_cheaperStay, _cheapestTransport]) {
      all = option(all.request, all.plan, catalog) ?? all;
    }
    all = _shorterTrip(all.request, all.plan) ?? all;
    final stillOverBy = _total(all, catalog) - request.budget;
    if (stillOverBy <= 0) return null;

    final province = catalog.province(plan.destinationId);
    int minimumFor(int days) => calculator.minimumTripCost(
      request: _lasting(request, days),
      province: province,
    );
    final minimum = minimumFor(request.dayCount);
    for (var days = request.dayCount - 1; days >= 1; days--) {
      final cost = minimumFor(days);
      if (cost <= request.budget) {
        return BudgetRescue(
          stillOverBy: stillOverBy,
          minimumBudget: _roundUpToHundred(minimum),
          daysThatFit: days,
          costOfDaysThatFit: cost,
        );
      }
    }
    return BudgetRescue(
      stillOverBy: stillOverBy,
      minimumBudget: _roundUpToHundred(minimum),
    );
  }

  int _total(_Change change, PlaceCatalog catalog) => calculator
      .applyCosts(request: change.request, plan: change.plan, catalog: catalog)
      .cost
      .total;

  /// Every night moves to the closest Accommodation of the nearest lower
  /// Price Level. Nights without accommodation data are left alone.
  _Change? _cheaperStay(
    TripRequest request,
    TripPlan plan,
    PlaceCatalog catalog,
  ) {
    if (plan.nightStays.isEmpty) return null;
    final current = catalog.place(plan.nightStays.first.placeId);
    final cheaper = [
      for (final place in catalog.placesIn(
        plan.destinationId,
        category: PlaceCategory.accommodation,
      ))
        if (place.priceLevel < current.priceLevel) place,
    ];
    if (cheaper.isEmpty) return null;

    final hotel = nightStayPlanner.pickAccommodation(
      tier: current.priceLevel - 1,
      near: current.location,
      accommodations: cheaper,
    );
    final losesBreakfast =
        current.breakfastIncluded && !hotel.breakfastIncluded;
    return (
      request: request,
      plan: plan.copyWith(
        nightStays: [
          for (final stay in plan.nightStays) stay.copyWith(placeId: hotel.id),
        ],
      ),
      label:
          'เปลี่ยนที่พักเป็น ${hotel.name} (${'฿' * hotel.priceLevel})'
          '${losesBreakfast ? ' ไม่รวมอาหารเช้า' : ''}',
    );
  }

  /// The Local Transport Mode that makes this plan cheapest, when it is
  /// not the one already chosen.
  _Change? _cheapestTransport(
    TripRequest request,
    TripPlan plan,
    PlaceCatalog catalog,
  ) {
    _Change using(LocalTransportMode mode) => (
      request: request.copyWith(localTransportMode: mode),
      plan: plan,
      label: 'เปลี่ยนเป็น${mode.label}',
    );

    var best = using(request.localTransportMode);
    var bestTotal = _total(best, catalog);
    for (final mode in LocalTransportMode.values) {
      final total = _total(using(mode), catalog);
      if (total < bestTotal) {
        best = using(mode);
        bestTotal = total;
      }
    }
    return best.request.localTransportMode == request.localTransportMode
        ? null
        : best;
  }

  /// Drops the last day and the night before it. The planner is not run
  /// again, so the remaining days keep their Stops.
  _Change? _shorterTrip(TripRequest request, TripPlan plan) {
    final days = plan.days.length - 1;
    if (days < 1) return null;
    return (
      request: _lasting(request, days),
      plan: plan.copyWith(
        days: plan.days.sublist(0, days),
        nightStays: [
          for (final stay in plan.nightStays)
            if (stay.night < days) stay,
        ],
      ),
      label: days == 1
          ? 'ลดเหลือ 1 วัน ไม่ค้างคืน'
          : 'ลดเหลือ $days วัน ${days - 1} คืน',
    );
  }

  /// The province whose cheapest trip undercuts the cheapest trip here by
  /// the most, skipping any to avoid in the month of travel.
  BudgetAdvice? _cheaperDestination(
    TripRequest request,
    TripPlan plan,
    PlaceCatalog catalog,
  ) {
    int minimumIn(Province province) =>
        calculator.minimumTripCost(request: request, province: province);

    final here = minimumIn(catalog.province(plan.destinationId));
    Province? best;
    var bestSaving = 0;
    for (final province in catalog.provinces) {
      if (province.id == plan.destinationId ||
          province.seasonFor(request.startDate.month) == SeasonRating.avoid) {
        continue;
      }
      final saving = here - minimumIn(province);
      if (saving > bestSaving) {
        best = province;
        bestSaving = saving;
      }
    }
    if (best == null) return null;
    return BudgetAdvice(
      kind: BudgetAdviceKind.changeDestination,
      saving: bestSaving,
      description:
          'เที่ยว${best.name}แทน เริ่มต้นถูกกว่า ~${_baht(bestSaving)}',
    );
  }

  /// [request] ending so that the trip lasts [days] days.
  static TripRequest _lasting(TripRequest request, int days) {
    final start = request.startDate;
    return request.copyWith(
      endDate: DateTime(start.year, start.month, start.day + days - 1),
    );
  }

  static int _roundUpToHundred(int baht) => (baht / 100).ceil() * 100;

  /// `6000` → `฿6,000`. The planner stays free of UI packages, so this
  /// does not use the formatter in `lib/shared`.
  static String _baht(int amount) {
    final digits = amount.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return '฿$grouped';
  }
}
