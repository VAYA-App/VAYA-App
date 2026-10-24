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
  static const defaultMealMinutes = 60;

  /// Meals start inside these windows (PROJECT-PLAN §10).
  static const lunchWindow = OpeningPeriod(
    ClockTime.hm(11, 30),
    ClockTime.hm(13, 30),
  );
  static const dinnerWindow = OpeningPeriod(
    ClockTime.hm(17, 30),
    ClockTime.hm(19, 30),
  );

  /// Assumed when a Place has no opening hours (with a warning).
  static const assumedHours = OpeningPeriod(
    ClockTime.hm(9, 0),
    ClockTime.hm(17, 0),
  );

  /// [start] is where the day begins: the previous night's accommodation,
  /// or the arrival point on the first day. [dayEnd] is when the travellers
  /// must leave (the last day's departure). Costs are left at 0 for the
  /// cost calculator (#34).
  ///
  /// A sight that is closed that day or cannot finish before closing is
  /// moved earlier in the day; if no move helps it is dropped with a day
  /// warning (PROJECT-PLAN §10.3). Other problems, and any problem with a
  /// meal or evening Stop, only add Thai warnings to the Stop.
  DayPlan orderDay({
    required DateTime date,
    required List<SlotPick> picks,
    required GeoPoint start,
    required ClockTime dayStart,
    required PlaceCatalog catalog,
    ClockTime? dayEnd,
  }) {
    SlotPick? lunch, dinner;
    final sights = <SlotPick>[], evening = <SlotPick>[];
    for (final pick in picks) {
      switch (pick.slot) {
        case Slot.lunch:
          lunch ??= pick;
        case Slot.dinner:
          dinner ??= pick;
        case Slot.evening:
          evening.add(pick);
        case Slot.morning || Slot.afternoon:
          sights.add(pick);
      }
    }

    List<Stop> schedule(List<SlotPick> order) => _schedule(
      order,
      lunch: lunch,
      dinner: dinner,
      evening: evening,
      date: date,
      start: start,
      dayStart: dayStart,
      dayEnd: dayEnd,
      catalog: catalog,
    );
    List<Stop> misfits(List<Stop> stops) => [
      for (final stop in stops)
        if (stop.slot case Slot.morning || Slot.afternoon
            when _closingProblem(stop, date, catalog) != null)
          stop,
    ];

    var order = nearestNeighbor(start, sights, catalog);
    final warnings = <String>[];
    while (true) {
      final stops = schedule(order);
      final bad = misfits(stops);
      if (bad.isEmpty) {
        return DayPlan(date: date, stops: stops, warnings: warnings);
      }
      final first = bad.first;
      final from = order.indexWhere((p) => p.placeId == first.placeId);
      final moved = [
        for (var to = 0; to < from; to++)
          [...order]
            ..removeAt(from)
            ..insert(to, order[from]),
      ].where((o) => misfits(schedule(o)).length < bad.length).firstOrNull;
      if (moved != null) {
        order = moved;
      } else {
        final place = catalog.place(first.placeId);
        warnings.add(
          'ตัด ${place.name} ออก เพราะ${_closingProblem(first, date, catalog)}',
        );
        order = [...order]..removeAt(from);
      }
    }
  }

  /// Why [stop] does not fit its Place's opening hours, or null when it
  /// does. Arriving before opening is not counted: the Stop keeps its
  /// warning instead.
  static String? _closingProblem(
    Stop stop,
    DateTime date,
    PlaceCatalog catalog,
  ) {
    final place = catalog.place(stop.placeId);
    final hours = place.hasKnownOpeningHours
        ? place.hoursOn(date)
        : assumedHours;
    if (hours == null) return 'ปิดในวันนี้';
    if (stop.end.isAfter(hours.close)) {
      return 'เที่ยวไม่ทันก่อนเวลาปิด (${hours.close})';
    }
    return null;
  }

  List<Stop> _schedule(
    List<SlotPick> sights, {
    required SlotPick? lunch,
    required SlotPick? dinner,
    required List<SlotPick> evening,
    required DateTime date,
    required GeoPoint start,
    required ClockTime dayStart,
    required ClockTime? dayEnd,
    required PlaceCatalog catalog,
  }) {
    final day = _DayBuilder(
      date: date,
      start: start,
      time: dayStart,
      dayEnd: dayEnd,
      catalog: catalog,
    );
    for (final sight in sights) {
      if (lunch != null && day.mealIsDue(lunchWindow, before: sight)) {
        day.visit(lunch, notBefore: lunchWindow.open);
        lunch = null;
      }
      if (dinner != null && day.mealIsDue(dinnerWindow, before: sight)) {
        day.visit(dinner, notBefore: dinnerWindow.open);
        dinner = null;
      }
      day.visit(sight);
    }
    if (lunch != null) day.visit(lunch, notBefore: lunchWindow.open);
    if (dinner != null) day.visit(dinner, notBefore: dinnerWindow.open);
    for (final night in nearestNeighbor(day.here, evening, catalog)) {
      day.visit(night);
    }
    return day.stops;
  }
}

/// Walks through a day, keeping the clock and the current position.
class _DayBuilder {
  _DayBuilder({
    required this.date,
    required GeoPoint start,
    required ClockTime time,
    required this.dayEnd,
    required this.catalog,
  }) : _here = start,
       _now = time;

  final DateTime date;
  final ClockTime? dayEnd;
  final PlaceCatalog catalog;
  final stops = <Stop>[];
  GeoPoint _here;
  ClockTime _now;

  GeoPoint get here => _here;

  int _durationOf(SlotPick pick) =>
      catalog.place(pick.placeId).dwellMinutes ??
      (pick.slot.isMeal
          ? RouteOrderer.defaultMealMinutes
          : RouteOrderer.defaultDwellMinutes);

  /// Eat now when it is already meal time, or when visiting [before] first
  /// would run past the end of the meal [window].
  bool mealIsDue(OpeningPeriod window, {required SlotPick before}) {
    if (!_now.isBefore(window.open)) return true;
    final travel = travelBetween(_here, catalog.place(before.placeId).location);
    final end = _now.addMinutes(travel.minutes + _durationOf(before));
    return end.isAfter(window.close);
  }

  /// Goes to [pick]; waits until [notBefore] if it arrives early.
  void visit(SlotPick pick, {ClockTime? notBefore}) {
    final place = catalog.place(pick.placeId);
    final travel = travelBetween(_here, place.location);
    var start = _now.addMinutes(travel.minutes);
    if (notBefore != null && start.isBefore(notBefore)) start = notBefore;
    final stop = Stop(
      placeId: place.id,
      slot: pick.slot,
      start: start,
      durationMin: _durationOf(pick),
      travelFromPrevMin: travel.minutes,
      travelFromPrevKm: travel.km,
      cost: 0,
      note: pick.note,
      warnings: _warningsFor(place, start, _durationOf(pick)),
    );
    stops.add(stop);
    _here = place.location;
    _now = stop.end;
  }

  List<String> _warningsFor(Place place, ClockTime start, int minutes) {
    final end = start.addMinutes(minutes);
    final hours = place.hasKnownOpeningHours
        ? place.hoursOn(date)
        : RouteOrderer.assumedHours;
    return [
      if (!place.hasKnownOpeningHours)
        'ไม่มีข้อมูลเวลาเปิด-ปิด ใช้ 09:00–17:00 แทน'
      else if (hours == null)
        'สถานที่ปิดในวันนี้'
      else if (start.isBefore(hours.open))
        'ไปถึงก่อนเวลาเปิด (${hours.open})'
      else if (end.isAfter(hours.close))
        'อาจปิดก่อนเที่ยวเสร็จ (ปิด ${hours.close})',
      if (dayEnd case final leave? when end.isAfter(leave))
        'เลยเวลาที่ควรออกเดินทางกลับ ($leave)',
    ];
  }
}
