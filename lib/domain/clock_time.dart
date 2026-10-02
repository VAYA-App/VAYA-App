/// A time of day in minutes since midnight, serialised as `"HH:mm"`.
///
/// Values past 24:00 are allowed so a late evening Stop can end after
/// midnight without wrapping.
final class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.minutesSinceMidnight)
    : assert(minutesSinceMidnight >= 0);

  const ClockTime.hm(int hour, int minute) : this(hour * 60 + minute);

  factory ClockTime.parse(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) {
      throw FormatException('Expected HH:mm', hhmm);
    }
    return ClockTime.hm(int.parse(parts[0]), int.parse(parts[1]));
  }

  factory ClockTime.fromJson(String json) => ClockTime.parse(json);

  final int minutesSinceMidnight;

  int get hour => minutesSinceMidnight ~/ 60;
  int get minute => minutesSinceMidnight % 60;

  ClockTime addMinutes(int minutes) =>
      ClockTime(minutesSinceMidnight + minutes);

  bool isBefore(ClockTime other) => compareTo(other) < 0;
  bool isAfter(ClockTime other) => compareTo(other) > 0;

  String toJson() => toString();

  @override
  int compareTo(ClockTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.minutesSinceMidnight == minutesSinceMidnight;

  @override
  int get hashCode => minutesSinceMidnight.hashCode;

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
