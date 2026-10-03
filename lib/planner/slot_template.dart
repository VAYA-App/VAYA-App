import '../domain/domain.dart';

/// The slots to fill on one day and the time window the day has.
final class DayTemplate {
  const DayTemplate({
    required this.date,
    required this.slots,
    required this.start,
    this.end,
  });

  final DateTime date;
  final List<Slot> slots;

  /// When the day's first trip leaves (hotel or arrival point).
  final ClockTime start;

  /// When the travellers must leave for home; `null` when they need not.
  final ClockTime? end;
}

/// Day structures per Pace (PROJECT-PLAN §8), trimmed on the first and last
/// day around Intercity Transport.
abstract final class SlotTemplate {
  static const dayStart = ClockTime.hm(9, 0);

  /// Assumed departure from the Origin on the first day.
  static const outboundDeparture = ClockTime.hm(8, 0);

  /// Assumed departure back home on the last day.
  static const returnDeparture = ClockTime.hm(17, 0);

  static const _byPace = {
    Pace.chill: [Slot.morning, Slot.lunch, Slot.afternoon, Slot.dinner],
    Pace.normal: [
      Slot.morning,
      Slot.lunch,
      Slot.afternoon,
      Slot.afternoon,
      Slot.dinner,
    ],
    Pace.packed: [
      Slot.morning,
      Slot.morning,
      Slot.lunch,
      Slot.afternoon,
      Slot.afternoon,
      Slot.dinner,
    ],
  };

  /// [intercityMinutes] is the one-way travel time; `null` when the trip
  /// stays in the Origin province.
  static List<DayTemplate> forTrip(
    TripRequest request, {
    int? intercityMinutes,
  }) {
    final base = [
      ..._byPace[request.pace]!,
      if (request.pace == Pace.packed &&
          request.preferenceTags.contains(PreferenceTag.nightlife))
        Slot.evening,
    ];
    final days = request.dayCount;

    return [
      for (var i = 0; i < days; i++)
        _day(
          date: request.startDate.add(Duration(days: i)),
          base: base,
          intercityMinutes: intercityMinutes,
          isFirst: i == 0,
          isLast: i == days - 1,
        ),
    ];
  }

  static DayTemplate _day({
    required DateTime date,
    required List<Slot> base,
    required int? intercityMinutes,
    required bool isFirst,
    required bool isLast,
  }) {
    var slots = [...base];
    var start = dayStart;
    ClockTime? end;

    if (intercityMinutes != null && isFirst) {
      final arrival = outboundDeparture.addMinutes(intercityMinutes);
      if (arrival.isAfter(start)) start = arrival;
      if (!arrival.isBefore(const ClockTime.hm(11, 0))) {
        slots.removeWhere((s) => s == Slot.morning);
      }
      if (!arrival.isBefore(const ClockTime.hm(13, 30))) {
        slots.remove(Slot.lunch);
      }
      if (!arrival.isBefore(const ClockTime.hm(15, 30))) {
        slots.remove(Slot.afternoon);
      }
    }
    if (intercityMinutes != null && isLast) {
      end = returnDeparture;
      slots.removeWhere((s) => s == Slot.dinner || s == Slot.evening);
    }
    return DayTemplate(date: date, slots: slots, start: start, end: end);
  }
}
