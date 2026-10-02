/// Dates without a time of day, serialised as `"yyyy-MM-dd"`.
library;

DateTime dateFromJson(String json) {
  final d = DateTime.parse(json);
  return DateTime(d.year, d.month, d.day);
}

String dateToJson(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
