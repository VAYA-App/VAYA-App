import '../../domain/domain.dart';

/// Saved Trips split by [today]: those still ahead (or under way), soonest
/// first, and those already over, latest first.
final class TripGroups {
  factory TripGroups(Iterable<Trip> trips, DateTime today) {
    final ahead = <Trip>[], past = <Trip>[];
    for (final t in trips) {
      (t.request.endDate.isBefore(today) ? past : ahead).add(t);
    }
    ahead.sort((a, b) => a.request.startDate.compareTo(b.request.startDate));
    past.sort((a, b) => b.request.startDate.compareTo(a.request.startDate));
    return TripGroups._(ahead, past);
  }

  const TripGroups._(this.ahead, this.past);

  final List<Trip> ahead;
  final List<Trip> past;

  /// The Upcoming Trip (CONTEXT.md), if any.
  Trip? get upcoming => ahead.firstOrNull;
}

/// How far off [trip] is from [today]: `อีก 12 วัน`, `พรุ่งนี้`, `วันนี้`
/// or `กำลังเที่ยว`.
String countdownLabel(Trip trip, DateTime today) {
  final days = trip.request.startDate.difference(today).inDays;
  return switch (days) {
    > 1 => 'อีก $days วัน',
    1 => 'พรุ่งนี้',
    0 => 'วันนี้',
    _ => 'กำลังเที่ยว',
  };
}
