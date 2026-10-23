import 'dart:math' as math;

import '../domain/domain.dart';
import 'cost_calculator.dart';
import 'geo.dart';
import 'over_budget_advisor.dart';
import 'route_orderer.dart';
import 'slot_template.dart';

/// One change to a Trip Plan, made by the user (#45) or proposed by the AI
/// chat (#46). [day] and [index] point at a Stop of the current plan.
sealed class PlanEdit {
  const PlanEdit({required this.day, required this.index});

  final int day;
  final int index;
}

final class RemoveStop extends PlanEdit {
  const RemoveStop({required super.day, required super.index});
}

final class ReplaceStop extends PlanEdit {
  const ReplaceStop({
    required super.day,
    required super.index,
    required this.placeId,
  });

  final String placeId;
}

/// Applies a [PlanEdit] and rebuilds what depends on it: the day's order
/// and times, the costs and the over-budget advice. The planning pipeline
/// uses [assemble] too, so an edited plan follows the same rules as a new
/// one.
class PlanEditor {
  const PlanEditor({
    required this.costCalculator,
    required this.overBudgetAdvisor,
    this.routeOrderer = const RouteOrderer(),
  });

  final CostCalculator costCalculator;
  final OverBudgetAdvisor overBudgetAdvisor;
  final RouteOrderer routeOrderer;

  /// Throws [ArgumentError] when [edit] does not fit [plan]: no such Stop,
  /// or a replacement that is unknown, in another province, of the wrong
  /// kind for the slot, or already in the plan.
  TripPlan apply(
    PlanEdit edit, {
    required TripPlan plan,
    required TripRequest request,
    required PlaceCatalog catalog,
  }) => applyAll([edit], plan: plan, request: request, catalog: catalog);

  /// Applies [edits] together, all pointing at Stops of [plan] as it is
  /// now, then rebuilds the plan once. Throws [ArgumentError] like [apply],
  /// and when two edits touch the same Stop or bring in the same Place.
  TripPlan applyAll(
    List<PlanEdit> edits, {
    required TripPlan plan,
    required TripRequest request,
    required PlaceCatalog catalog,
  }) {
    final picks = <List<SlotPick?>>[
      for (final day in plan.days)
        [
          for (final stop in day.stops)
            SlotPick(slot: stop.slot, placeId: stop.placeId, note: stop.note),
        ],
    ];
    final touched = <(int, int)>{};
    final added = <String>{};
    for (final edit in edits) {
      if (edit.day < 0 ||
          edit.day >= plan.days.length ||
          edit.index < 0 ||
          edit.index >= plan.days[edit.day].stops.length) {
        throw ArgumentError('No stop ${edit.index + 1} on day ${edit.day + 1}');
      }
      if (!touched.add((edit.day, edit.index))) {
        throw ArgumentError(
          'Stop ${edit.index + 1} on day ${edit.day + 1} is edited twice',
        );
      }
      final current = picks[edit.day][edit.index]!;
      switch (edit) {
        case RemoveStop():
          // Removed after all edits are read, so indices stay valid.
          picks[edit.day][edit.index] = null;
        case ReplaceStop(:final placeId):
          _checkReplacement(placeId, current.slot, plan, catalog);
          if (!added.add(placeId)) {
            throw ArgumentError('$placeId is added twice');
          }
          picks[edit.day][edit.index] = SlotPick(
            slot: current.slot,
            placeId: placeId,
          );
      }
    }

    return assemble(
      request: request,
      catalog: catalog,
      destinationId: plan.destinationId,
      intercity: plan.intercity,
      nightStays: plan.nightStays,
      picks: [for (final day in picks) day.nonNulls.toList()],
    );
  }

  void _checkReplacement(
    String placeId,
    Slot slot,
    TripPlan plan,
    PlaceCatalog catalog,
  ) {
    final place = catalog.findPlace(placeId);
    if (place == null) throw ArgumentError('Unknown place $placeId');
    if (place.provinceId != plan.destinationId) {
      throw ArgumentError('$placeId is not in ${plan.destinationId}');
    }
    if (place.category != _categoryFor(slot)) {
      throw ArgumentError('$placeId cannot fill a ${slot.name} slot');
    }
    if (_placeIdsIn(plan).contains(placeId)) {
      throw ArgumentError('$placeId is already in the plan');
    }
  }

  /// Up to [count] Places that could replace the Stop: same kind, same
  /// province, not in the plan yet nor [excluded] (disliked, #49), closest
  /// first.
  static List<Place> alternatives(
    TripPlan plan,
    PlaceCatalog catalog, {
    required int day,
    required int index,
    int count = 5,
    Set<String> excluded = const {},
  }) {
    final stop = plan.days[day].stops[index];
    final here = catalog.place(stop.placeId).location;
    final used = {..._placeIdsIn(plan), ...excluded};
    final options =
        [
          for (final place in catalog.placesIn(
            plan.destinationId,
            category: _categoryFor(stop.slot),
          ))
            if (!used.contains(place.id)) place,
        ]..sort(
          (a, b) => haversineKm(
            here,
            a.location,
          ).compareTo(haversineKm(here, b.location)),
        );
    return options.sublist(0, math.min(count, options.length));
  }

  /// Orders and times every day, then prices the plan and adds advice when
  /// it is over budget. Day one starts at the province centre (the arrival
  /// point); later days at the first night's accommodation.
  TripPlan assemble({
    required TripRequest request,
    required PlaceCatalog catalog,
    required String destinationId,
    required IntercityLeg? intercity,
    required List<NightStay> nightStays,
    required List<List<SlotPick>> picks,
  }) {
    final province = catalog.province(destinationId);
    final templates = SlotTemplate.forTrip(
      request,
      intercityMinutes: intercity?.durationMin,
    );
    final hotel = nightStays.isEmpty
        ? null
        : catalog.place(nightStays.first.placeId).location;
    final days = [
      for (final (i, day) in templates.indexed)
        routeOrderer.orderDay(
          date: day.date,
          picks: i < picks.length ? picks[i] : const [],
          start: i == 0 ? province.center : hotel ?? province.center,
          dayStart: day.start,
          dayEnd: day.end,
          catalog: catalog,
        ),
    ];

    final priced = costCalculator.applyCosts(
      request: request,
      plan: TripPlan(
        destinationId: destinationId,
        status: PlanStatus.ok,
        intercity: intercity,
        nightStays: nightStays,
        days: days,
        cost: CostEstimate.unpriced(request.budget),
      ),
      catalog: catalog,
    );
    return priced.copyWith(
      overBudgetAdvice: priced.cost.isOverBudget
          ? overBudgetAdvisor.advise(
              request: request,
              plan: priced,
              catalog: catalog,
            )
          : const [],
    );
  }

  static PlaceCategory _categoryFor(Slot slot) =>
      slot.isMeal ? PlaceCategory.restaurant : PlaceCategory.attraction;

  static Set<String> _placeIdsIn(TripPlan plan) => {
    for (final day in plan.days)
      for (final stop in day.stops) stop.placeId,
  };
}
