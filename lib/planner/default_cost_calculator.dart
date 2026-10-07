import 'dart:math' as math;

import '../domain/domain.dart';
import 'candidate_builder.dart';
import 'cost_calculator.dart';
import 'geo.dart';
import 'pricing_table.dart';
import 'slot_template.dart';

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
  }) {
    final options = request.staysInOrigin(province.id)
        ? null
        : province.intercity[request.originId];
    if (options == null || options.isEmpty) return _minimumFor(request);
    return [
      for (final MapEntry(key: mode, value: option) in options.entries)
        _minimumFor(request, mode: mode, option: option),
    ].reduce(math.min);
  }

  /// The cheapest trip that travels by [mode]: Price Level 1 rooms and
  /// meals, free attractions, an Accommodation that includes breakfast, no
  /// distance between Stops and the cheapest Local Transport Mode. It never
  /// exceeds what [applyCosts] gives a plan the pipeline builds, so a
  /// province above the Budget here cannot fit it.
  int _minimumFor(
    TripRequest request, {
    IntercityMode? mode,
    IntercityOption? option,
  }) {
    final travellers = request.travellerCount;
    // The same day structure the pipeline fills.
    final days = SlotTemplate.forTrip(
      request,
      intercityMinutes: option?.durationMin,
    );
    final nights = days.length - 1;
    var meals = 0;
    var legs = 0;
    for (final (i, day) in days.indexed) {
      if (day.slots.isEmpty) continue;
      meals += day.slots.where((slot) => slot.isMeal).length;
      legs += day.slots.length;
      if (i < nights || days.length == 1) legs++;
    }

    final intercity = option == null || mode == null
        ? 0
        : _fare(option, mode, travellers);
    final accommodation = pricing.roomFor(1) * (travellers / 2).ceil() * nights;
    final food =
        pricing.mealFor(1) * travellers * meals +
        pricing.breakfastPerPerson * travellers;
    final localTransport = [
      for (final local in LocalTransportMode.values)
        _localCost(
          local,
          days: days.length,
          legs: legs,
          travellers: travellers,
        ),
    ].reduce(math.min);

    final subtotal = intercity + accommodation + food + localTransport;
    return subtotal + (subtotal * pricing.bufferRate).round();
  }

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

    return _localCost(
      request.localTransportMode,
      days: dayCount,
      legs: legs,
      km: km,
      travellers: request.travellerCount,
    );
  }

  int _localCost(
    LocalTransportMode mode, {
    required int days,
    required int legs,
    required int travellers,
    double km = 0,
  }) {
    final rate = pricing.rateFor(mode);
    final perUnit = rate.perDay * days + rate.perTrip * legs + rate.perKm * km;
    return (perUnit * rate.unitsFor(travellers)).round();
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

  int _intercityCost(
    TripRequest request,
    Province province,
    IntercityMode mode,
  ) {
    final options = province.intercity[request.originId];
    if (options == null || options.isEmpty) return 0;
    // Same fallback as the pipeline when the route lacks the chosen mode.
    return _fare(
      options[mode] ?? options.values.first,
      mode,
      request.travellerCount,
    );
  }

  /// Both directions. Tickets are per person; a car pays fuel and the toll
  /// once per direction whatever the number of travellers.
  int _fare(IntercityOption option, IntercityMode mode, int travellers) {
    if (mode == IntercityMode.car) {
      final fuel = (option.distanceKm ?? 0) * pricing.selfDrivePerKm;
      return ((fuel + option.toll) * 2).round();
    }
    return option.farePerPerson * travellers * 2;
  }
}

extension on IntercityLeg {
  IntercityLeg copyWithCost(int cost) =>
      IntercityLeg(mode: mode, durationMin: durationMin, cost: cost);
}
