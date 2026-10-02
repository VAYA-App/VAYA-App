import '../domain/domain.dart';
import 'geo.dart';

/// A Place that Gemini (#27) or the fallback scorer (#28) put into a slot
/// of one day.
final class SlotPick {
  const SlotPick({required this.slot, required this.placeId, this.note});

  final Slot slot;
  final String placeId;

  /// Short reason shown under the Stop.
  final String? note;
}

/// Orders [picks] greedily: always go to the closest unvisited Place next.
List<SlotPick> nearestNeighbor(
  GeoPoint start,
  List<SlotPick> picks,
  PlaceCatalog catalog,
) {
  final left = [...picks];
  final ordered = <SlotPick>[];
  var here = start;
  while (left.isNotEmpty) {
    left.sort(
      (a, b) => haversineKm(
        here,
        catalog.place(a.placeId).location,
      ).compareTo(haversineKm(here, catalog.place(b.placeId).location)),
    );
    final next = left.removeAt(0);
    ordered.add(next);
    here = catalog.place(next.placeId).location;
  }
  return ordered;
}

/// Turns one day's picks into timed Stops (PROJECT-PLAN §10). Pure and
/// deterministic: Gemini only chooses Places, this decides order and time.
class RouteOrderer {
  const RouteOrderer();

  /// Used when a Place has no `dwellMinutes`.
  static const defaultDwellMinutes = 90;

  /// [start] is where the day begins: the previous night's accommodation,
  /// or the arrival point on the first day. Costs are left at 0 for the
  /// cost calculator (#34).
  DayPlan orderDay({
    required DateTime date,
    required List<SlotPick> picks,
    required GeoPoint start,
    required ClockTime dayStart,
    required PlaceCatalog catalog,
  }) {
    final day = _DayBuilder(start: start, time: dayStart, catalog: catalog);
    for (final pick in nearestNeighbor(start, picks, catalog)) {
      day.visit(pick);
    }
    return DayPlan(date: date, stops: day.stops);
  }
}

/// Walks through a day, keeping the clock and the current position.
class _DayBuilder {
  _DayBuilder({
    required GeoPoint start,
    required ClockTime time,
    required this.catalog,
  }) : _here = start,
       _now = time;

  final PlaceCatalog catalog;
  final stops = <Stop>[];
  GeoPoint _here;
  ClockTime _now;

  void visit(SlotPick pick) {
    final place = catalog.place(pick.placeId);
    final travel = travelBetween(_here, place.location);
    final stop = Stop(
      placeId: place.id,
      slot: pick.slot,
      start: _now.addMinutes(travel.minutes),
      durationMin: place.dwellMinutes ?? RouteOrderer.defaultDwellMinutes,
      travelFromPrevMin: travel.minutes,
      travelFromPrevKm: travel.km,
      cost: 0,
      note: pick.note,
    );
    stops.add(stop);
    _here = place.location;
    _now = stop.end;
  }
}
