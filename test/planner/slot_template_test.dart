import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/slot_template.dart';

import 'test_data.dart';

void main() {
  const m = Slot.morning, l = Slot.lunch, a = Slot.afternoon, d = Slot.dinner;

  test('slots per pace without intercity travel', () {
    expect(SlotTemplate.forTrip(demoRequest(pace: Pace.chill)).first.slots, [
      m,
      l,
      a,
      d,
    ]);
    expect(SlotTemplate.forTrip(demoRequest(pace: Pace.normal)).first.slots, [
      m,
      l,
      a,
      a,
      d,
    ]);
    expect(SlotTemplate.forTrip(demoRequest(pace: Pace.packed)).first.slots, [
      m,
      m,
      l,
      a,
      a,
      d,
    ]);
  });

  test('packed trips with nightlife get an evening slot', () {
    final days = SlotTemplate.forTrip(
      demoRequest(pace: Pace.packed, tags: {PreferenceTag.nightlife}),
    );
    expect(days.first.slots.last, Slot.evening);
  });

  test('one template per day with consecutive dates and a 09:00 start', () {
    final days = SlotTemplate.forTrip(demoRequest(end: DateTime(2026, 11, 16)));
    expect(days.map((d) => d.date), [
      DateTime(2026, 11, 14),
      DateTime(2026, 11, 15),
      DateTime(2026, 11, 16),
    ]);
    expect(
      days.every((d) => d.start == SlotTemplate.dayStart && d.end == null),
      isTrue,
    );
  });

  test('first day starts on arrival and drops slots already over', () {
    List<Slot> firstDay(int minutes) => SlotTemplate.forTrip(
      demoRequest(),
      intercityMinutes: minutes,
    ).first.slots;

    final bus = SlotTemplate.forTrip(
      demoRequest(),
      intercityMinutes: 150,
    ).first;
    expect(bus.start, const ClockTime.hm(10, 30));
    expect(bus.slots, [m, l, a, d]);
    expect(firstDay(240), [l, a, d]); // arrives 12:00
    expect(firstDay(360), [a, d]); // arrives 14:00
    expect(firstDay(480), [d]); // arrives 16:00
  });

  test('last day ends at the return departure without dinner', () {
    final last = SlotTemplate.forTrip(
      demoRequest(),
      intercityMinutes: 150,
    ).last;
    expect(last.end, SlotTemplate.returnDeparture);
    expect(last.slots, [m, l, a]);
  });

  test('a day trip away is trimmed at both ends', () {
    final only = SlotTemplate.forTrip(
      demoRequest(end: DateTime(2026, 11, 14)),
      intercityMinutes: 150,
    ).single;
    expect(only.start, const ClockTime.hm(10, 30));
    expect(only.end, SlotTemplate.returnDeparture);
    expect(only.slots, [m, l, a]);
  });
}
