import '../domain/domain.dart';
import 'candidate_builder.dart';
import 'cost_calculator.dart';
import 'geo.dart';
import 'pricing_table.dart';

/// Prices a Trip Plan from [pricing] (PROJECT-PLAN §9). Every category is
/// rounded to whole baht before the buffer is added, so the categories and
/// the buffer always add up to the total.
class DefaultCostCalculator implements CostCalculator {
  const DefaultCostCalculator(this.pricing);

  final PricingTable pricing;

  @override
  TripPlan applyCosts({
    required TripRequest request,
    required TripPlan plan,
    required PlaceCatalog catalog,
  }) {
    final travellers = request.travellerCount;
    final province = catalog.province(plan.destinationId);

    final nightStays = [
      for (final stay in plan.nightStays)
        stay.copyWith(
          cost:
              pricing.roomFor(catalog.place(stay.placeId).priceLevel) *
              stay.rooms,
        ),
    ];
    final days = [
      for (final day in plan.days)
        day.copyWith(
          stops: [
            for (final stop in day.stops)
              stop.copyWith(
                cost: _stopCost(catalog.place(stop.placeId), travellers),
              ),
          ],
        ),
    ];
    final intercity = switch (plan.intercity) {
      final leg? => leg.copyWithCost(
        _intercityCost(request, province, leg.mode),
      ),
      null => null,
    };

    var meals = 0;
    var entrance = 0;
    for (final stop in days.expand((d) => d.stops)) {
      switch (catalog.place(stop.placeId).category) {
        case PlaceCategory.restaurant:
          meals += stop.cost;
        case PlaceCategory.attraction:
          entrance += stop.cost;
        case PlaceCategory.accommodation:
      }
    }

    final accommodation =
        nightStays.fold(0, (sum, stay) => sum + stay.cost) +
        _unplannedNights(request, plan);
    final food = meals + _breakfast(plan, catalog, travellers);
    final localTransport = _localTransport(request, plan, catalog, province);
    final intercityCost = intercity?.cost ?? 0;

    final subtotal =
        intercityCost + accommodation + food + entrance + localTransport;
    final buffer = (subtotal * pricing.bufferRate).round();
    final total = subtotal + buffer;
    final cost = CostEstimate(
      intercity: intercityCost,
      accommodation: accommodation,
      food: food,
      entrance: entrance,
      localTransport: localTransport,
      buffer: buffer,
      total: total,
      perPerson: (total / travellers).ceil(),
      budget: request.budget,
    );

    return plan.copyWith(
      status: cost.isOverBudget ? PlanStatus.overBudget : PlanStatus.ok,
      intercity: () => intercity,
      nightStays: nightStays,
      days: days,
      cost: cost,
    );
  }

  @override
  int minimumTripCost({
    required TripRequest request,
    required Province province,
  }) => throw UnimplementedError('minimumTripCost: see #35');

  /// A meal or an entrance fee for all travellers. A missing entrance fee
  /// counts as free because the data cannot tell the two apart yet.
  int _stopCost(Place place, int travellers) => switch (place.category) {
    PlaceCategory.restaurant => pricing.mealFor(place.priceLevel) * travellers,
    PlaceCategory.attraction => place.entranceFee * travellers,
    PlaceCategory.accommodation => 0,
  };

  /// Nights the plan has no Accommodation for (the province has no data)
  /// still cost a room, at the Price Level the budget allows.
  int _unplannedNights(TripRequest request, TripPlan plan) {
    final nights = plan.days.length - 1 - plan.nightStays.length;
    if (nights <= 0) return 0;
    final rooms = (request.travellerCount / 2).ceil();
    return pricing.roomFor(CandidateBuilder.priceCap(request)) * rooms * nights;
  }

  /// One breakfast per person per day, except the mornings after a night
  /// at an Accommodation that includes it. The first morning is always paid.
  int _breakfast(TripPlan plan, PlaceCatalog catalog, int travellers) {
    final included = plan.nightStays
        .where((stay) => catalog.place(stay.placeId).breakfastIncluded)
        .length;
    final paid = plan.days.length - included;
    return paid <= 0 ? 0 : pricing.breakfastPerPerson * travellers * paid;
  }

  /// Every Stop is one leg. Each night adds the leg back to the
  /// Accommodation, and a one-day trip the leg back to where it started;
  /// the last day of an overnight trip ends with the Intercity Transport.
  int _localTransport(
    TripRequest request,
    TripPlan plan,
    PlaceCatalog catalog,
    Province province,
  ) {
    final dayCount = plan.days.length;
    var legs = 0;
    var km = 0.0;
    for (final (i, day) in plan.days.indexed) {
      if (day.stops.isEmpty) continue;
      for (final stop in day.stops) {
        legs++;
        // Already stretched by the road factor (geo.dart).
        km += stop.travelFromPrevKm;
      }
      final sleepsHere = i < dayCount - 1;
      if (sleepsHere || dayCount == 1) {
        final last = catalog.place(day.stops.last.placeId).location;
        legs++;
        km += travelBetween(last, _base(plan, catalog, province, i + 1)).km;
      }
    }

    final rate = pricing.rateFor(request.localTransportMode);
    final perUnit =
        rate.perDay * dayCount + rate.perTrip * legs + rate.perKm * km;
    return (perUnit * rate.unitsFor(request.travellerCount)).round();
  }

  /// Where the travellers return to after the day before [night]: that
  /// night's Accommodation, or the province centre the pipeline uses as the
  /// starting point when there is none.
  GeoPoint _base(
    TripPlan plan,
    PlaceCatalog catalog,
    Province province,
    int night,
  ) {
    for (final stay in plan.nightStays) {
      if (stay.night == night) return catalog.place(stay.placeId).location;
    }
    return province.center;
  }

  /// Both directions. Tickets are per person; a car pays fuel and the toll
  /// once per direction whatever the number of travellers.
  int _intercityCost(
    TripRequest request,
    Province province,
    IntercityMode mode,
  ) {
    final options = province.intercity[request.originId];
    if (options == null || options.isEmpty) return 0;
    // Same fallback as the pipeline when the route lacks the chosen mode.
    final option = options[mode] ?? options.values.first;
    if (mode == IntercityMode.car) {
      final fuel = (option.distanceKm ?? 0) * pricing.selfDrivePerKm;
      return ((fuel + option.toll) * 2).round();
    }
    return option.farePerPerson * request.travellerCount * 2;
  }
}

extension on IntercityLeg {
  IntercityLeg copyWithCost(int cost) =>
      IntercityLeg(mode: mode, durationMin: durationMin, cost: cost);
}
