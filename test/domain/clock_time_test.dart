import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';

void main() {
  test('parses and formats HH:mm', () {
    final t = ClockTime.parse('09:05');

    expect(t.hour, 9);
    expect(t.minute, 5);
    expect(t.toJson(), '09:05');
  });

  test('adds minutes past the hour and past midnight', () {
    expect(ClockTime.parse('10:45').addMinutes(30).toJson(), '11:15');
    expect(ClockTime.parse('23:30').addMinutes(60).toJson(), '24:30');
  });

  test('compares by time of day', () {
    final morning = ClockTime.parse('08:00');
    final noon = ClockTime.parse('12:00');

    expect(morning.isBefore(noon), isTrue);
    expect(noon.isAfter(morning), isTrue);
    expect(ClockTime.hm(8, 0), morning);
  });

  test('opening period excludes the closing minute', () {
    final hours = OpeningPeriod.fromJson(['09:00', '17:00']);

    expect(hours.contains(ClockTime.parse('09:00')), isTrue);
    expect(hours.contains(ClockTime.parse('16:59')), isTrue);
    expect(hours.contains(ClockTime.parse('17:00')), isFalse);
  });

  test('rejects malformed input', () {
    expect(() => ClockTime.parse('0900'), throwsFormatException);
  });
}
