import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/route_orderer.dart';

/// 2026-11-16 is a Monday.
final monday = DateTime(2026, 11, 16);
const start = GeoPoint(13, 100);

Place place(
  String id,
  double lng, {
  PlaceCategory category = PlaceCategory.attraction,
  int? dwell,
  Map<int, OpeningPeriod>? hours = const {},
}) => Place(
  id: id,
  provinceId: 'test',
  category: category,
  name: id,
  location: GeoPoint(13, lng),
  tags: const [],
  priceLevel: 1,
  shortDescription: id,
  dwellMinutes: dwell,
  // Default: open every day 08:00–22:00.
  openingHours: hours != null && hours.isEmpty
      ? {
          for (var d = 1; d <= 7; d++)
            d: const OpeningPeriod(ClockTime.hm(8, 0), ClockTime.hm(22, 0)),
        }
      : hours,
);

PlaceCatalog catalogOf(List<Place> places) =>
    PlaceCatalog(provinces: const [], places: places);

SlotPick pick(Slot slot, String id) => SlotPick(slot: slot, placeId: id);

DayPlan order(
  List<Place> places,
  List<SlotPick> picks, {
  ClockTime dayStart = const ClockTime.hm(9, 0),
  ClockTime? dayEnd,
}) => const RouteOrderer().orderDay(
  date: monday,
  picks: picks,
  start: start,
  dayStart: dayStart,
  dayEnd: dayEnd,
  catalog: catalogOf(places),
);

List<String> ids(DayPlan day) => [for (final s in day.stops) s.placeId];

void main() {
  final a = place('a', 100.01), b = place('b', 100.02), c = place('c', 100.03);
  final lunch = place('lunch', 100.025, category: PlaceCategory.restaurant);
  final dinner = place('dinner', 100.015, category: PlaceCategory.restaurant);

  test('visits attractions nearest first from the start', () {
    final day = order(
      [a, b, c],
      [
        pick(Slot.afternoon, 'c'),
        pick(Slot.morning, 'a'),
        pick(Slot.morning, 'b'),
      ],
    );

    expect(ids(day), ['a', 'b', 'c']);
  });

  test('stops follow each other with travel time and never overlap', () {
    final day = order(
      [a, b, c, lunch, dinner],
      [
        pick(Slot.morning, 'a'),
        pick(Slot.morning, 'b'),
        pick(Slot.afternoon, 'c'),
        pick(Slot.lunch, 'lunch'),
        pick(Slot.dinner, 'dinner'),
      ],
    );

    expect(
      day.stops.first.start,
      const ClockTime.hm(9, 0).addMinutes(day.stops.first.travelFromPrevMin),
    );
    for (var i = 1; i < day.stops.length; i++) {
      final prev = day.stops[i - 1], stop = day.stops[i];
      expect(
        stop.start.isBefore(prev.end.addMinutes(stop.travelFromPrevMin)),
        isFalse,
        reason: '${stop.placeId} starts before ${prev.placeId} ends',
      );
    }
  });

  test('uses dwell minutes, 90 for sights and 60 for meals by default', () {
    final short = place('short', 100.01, dwell: 30);
    final day = order(
      [short, b, lunch],
      [
        pick(Slot.morning, 'short'),
        pick(Slot.morning, 'b'),
        pick(Slot.lunch, 'lunch'),
      ],
    );

    expect(
      {for (final s in day.stops) s.placeId: s.durationMin},
      {'short': 30, 'b': 90, 'lunch': 60},
    );
  });

  test('meals start inside their windows', () {
    final day = order(
      [a, b, c, lunch, dinner],
      [
        pick(Slot.morning, 'a'),
        pick(Slot.morning, 'b'),
        pick(Slot.afternoon, 'c'),
        pick(Slot.lunch, 'lunch'),
        pick(Slot.dinner, 'dinner'),
      ],
    );
    final byId = {for (final s in day.stops) s.placeId: s};

    expect(RouteOrderer.lunchWindow.contains(byId['lunch']!.start), isTrue);
    expect(RouteOrderer.dinnerWindow.contains(byId['dinner']!.start), isTrue);
    expect(ids(day), ['a', 'b', 'lunch', 'c', 'dinner']);
  });

  test('eats lunch first when the next sight would run past the window', () {
    final long = place('long', 100.01, dwell: 240);
    final day = order(
      [long, lunch],
      [pick(Slot.morning, 'long'), pick(Slot.lunch, 'lunch')],
      dayStart: const ClockTime.hm(11, 0),
    );

    expect(ids(day), ['lunch', 'long']);
    expect(day.stops.first.start, RouteOrderer.lunchWindow.open);
  });

  test('evening stops come after dinner', () {
    final bar = place('bar', 100.005);
    final day = order(
      [a, bar, dinner],
      [
        pick(Slot.evening, 'bar'),
        pick(Slot.afternoon, 'a'),
        pick(Slot.dinner, 'dinner'),
      ],
      dayStart: const ClockTime.hm(14, 0),
    );

    expect(ids(day), ['a', 'dinner', 'bar']);
  });

  test('keeps the note from the pick and leaves cost for the calculator', () {
    final day = const RouteOrderer().orderDay(
      date: monday,
      picks: const [SlotPick(slot: Slot.morning, placeId: 'a', note: 'วิวดี')],
      start: start,
      dayStart: const ClockTime.hm(9, 0),
      catalog: catalogOf([a]),
    );

    expect(day.stops.single.note, 'วิวดี');
    expect(day.stops.single.cost, 0);
    expect(day.date, monday);
  });

  group('warnings', () {
    List<String> warningsFor(
      Place p, {
      ClockTime dayStart = const ClockTime.hm(9, 0),
      ClockTime? dayEnd,
    }) => order(
      [p],
      [pick(Slot.morning, p.id)],
      dayStart: dayStart,
      dayEnd: dayEnd,
    ).stops.single.warnings;

    test('none when open the whole visit', () {
      expect(warningsFor(a), isEmpty);
    });

    test('unknown opening hours', () {
      expect(warningsFor(place('x', 100.01, hours: null)), [
        'ไม่มีข้อมูลเวลาเปิด-ปิด ใช้ 09:00–17:00 แทน',
      ]);
    });

    test('closed on that weekday', () {
      final weekendOnly = place(
        'x',
        100.01,
        hours: {
          DateTime.saturday: const OpeningPeriod(
            ClockTime.hm(9, 0),
            ClockTime.hm(18, 0),
          ),
        },
      );
      expect(warningsFor(weekendOnly), ['สถานที่ปิดในวันนี้']);
    });

    test('arrives before opening', () {
      final late = place(
        'x',
        100.01,
        hours: {
          DateTime.monday: const OpeningPeriod(
            ClockTime.hm(10, 0),
            ClockTime.hm(18, 0),
          ),
        },
      );
      expect(warningsFor(late), ['ไปถึงก่อนเวลาเปิด (10:00)']);
    });

    test('closes before the visit ends', () {
      final early = place(
        'x',
        100.01,
        hours: {
          DateTime.monday: const OpeningPeriod(
            ClockTime.hm(8, 0),
            ClockTime.hm(10, 0),
          ),
        },
      );
      expect(warningsFor(early), ['อาจปิดก่อนเที่ยวเสร็จ (ปิด 10:00)']);
    });

    test('runs past the departure time', () {
      expect(warningsFor(a, dayEnd: const ClockTime.hm(10, 0)), [
        'เลยเวลาที่ควรออกเดินทางกลับ (10:00)',
      ]);
    });
  });

  test('an empty day has no stops', () {
    expect(order([], []).stops, isEmpty);
  });
}
