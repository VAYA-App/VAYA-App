import 'package:intl/intl.dart';

final _baht = NumberFormat('#,##0', 'en_US');

/// `6000` → `฿6,000`.
String formatBaht(int amount) => '฿${_baht.format(amount)}';

const _weekdays = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
const _months = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

/// `2026-11-14` → `ส. 14 พ.ย.`
String formatThaiShortDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

/// `2026-11-14` → `พ.ย.`
String formatThaiMonth(DateTime date) => _months[date.month - 1];

/// `2026-11-14`, `2026-11-15` → `14–15 พ.ย.`
String formatDateRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    if (start.day == end.day) {
      return '${start.day} ${_months[start.month - 1]}';
    }
    return '${start.day}–${end.day} ${_months[start.month - 1]}';
  }
  return '${start.day} ${_months[start.month - 1]} – ${end.day} ${_months[end.month - 1]}';
}

/// `2026-11-14`, `2026-11-15` → `2 วัน 1 คืน`; a single day is a day trip.
String formatTripLength(DateTime start, DateTime end) {
  final days = end.difference(start).inDays + 1;
  return days == 1 ? 'ไปเช้าเย็นกลับ' : '$days วัน ${days - 1} คืน';
}
