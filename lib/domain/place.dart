import 'clock_time.dart';
import 'enums.dart';
import 'geo_point.dart';

/// A real Attraction, Restaurant or Accommodation inside a Destination,
/// loaded from `assets/data/places/<provinceId>.json`.
final class Place {
  const Place({
    required this.id,
    required this.provinceId,
    required this.category,
    required this.name,
    required this.location,
    required this.tags,
    required this.priceLevel,
    required this.shortDescription,
    this.area,
    this.rating,
    this.openingHours,
    this.dwellMinutes,
    this.entranceFee = 0,
    this.breakfastIncluded = false,
  }) : assert(priceLevel >= 1 && priceLevel <= 4);

  factory Place.fromJson(Map<String, Object?> json) {
    final hours = json['openingHours'] as Map<String, Object?>?;
    return Place(
      id: json['id'] as String,
      provinceId: json['provinceId'] as String,
      category: PlaceCategory.values.byName(json['category'] as String),
      name: json['name'] as String,
      area: json['area'] as String?,
      location: GeoPoint.fromJson(json['location'] as Map<String, Object?>),
      tags: [
        for (final t in json['tags'] as List) PreferenceTag.values.byName(t),
      ],
      priceLevel: (json['priceLevel'] as num).toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      openingHours: hours == null
          ? null
          : {
              for (final e in hours.entries)
                _weekdayFromKey(e.key): OpeningPeriod.fromJson(e.value as List),
            },
      dwellMinutes: (json['dwellMinutes'] as num?)?.toInt(),
      entranceFee: (json['entranceFee'] as num?)?.toInt() ?? 0,
      shortDescription: json['shortDescription'] as String,
      breakfastIncluded: json['breakfastIncluded'] as bool? ?? false,
    );
  }

  final String id;
  final String provinceId;
  final PlaceCategory category;
  final String name;

  /// Neighbourhood shown to users, e.g. "พัทยา" or "บางแสน".
  final String? area;
  final GeoPoint location;
  final List<PreferenceTag> tags;

  /// ฿ to ฿฿฿฿ as 1–4. Converted to baht with `assets/data/pricing.json`.
  final int priceLevel;
  final double? rating;

  /// Keyed by [DateTime.weekday]. `null` means unknown (planner assumes
  /// 09:00–17:00 and warns); a missing weekday means closed that day.
  final Map<int, OpeningPeriod>? openingHours;

  /// Typical visit length for attractions and restaurants.
  final int? dwellMinutes;

  /// Baht per person; attractions only.
  final int entranceFee;
  final String shortDescription;

  /// Accommodation only.
  final bool breakfastIncluded;

  bool get hasKnownOpeningHours => openingHours != null;

  /// Opening hours on [date], or `null` when closed or unknown.
  OpeningPeriod? hoursOn(DateTime date) => openingHours?[date.weekday];

  Map<String, Object?> toJson() => {
    'id': id,
    'provinceId': provinceId,
    'category': category.name,
    'name': name,
    if (area != null) 'area': area,
    'location': location.toJson(),
    'tags': [for (final t in tags) t.name],
    'priceLevel': priceLevel,
    if (rating != null) 'rating': rating,
    if (openingHours != null)
      'openingHours': {
        for (final e in openingHours!.entries)
          _weekdayKeys[e.key - 1]: e.value.toJson(),
      },
    if (dwellMinutes != null) 'dwellMinutes': dwellMinutes,
    if (entranceFee != 0) 'entranceFee': entranceFee,
    'shortDescription': shortDescription,
    if (breakfastIncluded) 'breakfastIncluded': true,
  };

  static const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  static int _weekdayFromKey(String key) {
    final index = _weekdayKeys.indexOf(key);
    if (index < 0) throw FormatException('Unknown weekday', key);
    return index + 1;
  }
}

/// Serialised as `["09:00", "17:00"]`.
final class OpeningPeriod {
  const OpeningPeriod(this.open, this.close);

  factory OpeningPeriod.fromJson(List json) => OpeningPeriod(
    ClockTime.parse(json[0] as String),
    ClockTime.parse(json[1] as String),
  );

  final ClockTime open;
  final ClockTime close;

  bool contains(ClockTime time) => !time.isBefore(open) && time.isBefore(close);

  List<String> toJson() => [open.toJson(), close.toJson()];
}
