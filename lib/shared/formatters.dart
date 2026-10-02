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
