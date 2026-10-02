import 'enums.dart';
import 'geo_point.dart';

/// A Destination the system supports, loaded from `assets/data/provinces.json`.
final class Province {
  const Province({
    required this.id,
    required this.name,
    required this.center,
    required this.regionTag,
    required this.tags,
    required this.seasonality,
    required this.seasonNote,
    required this.intercity,
  }) : assert(seasonality.length == 12);

  factory Province.fromJson(Map<String, Object?> json) => Province(
    id: json['id'] as String,
    name: json['name'] as String,
    center: GeoPoint.fromJson(json['center'] as Map<String, Object?>),
    regionTag: json['regionTag'] as String,
    tags: [
      for (final t in json['tags'] as List) PreferenceTag.values.byName(t),
    ],
    seasonality: [
      for (final s in json['seasonality'] as List)
        SeasonRating.values.byName(s),
    ],
    seasonNote: json['seasonNote'] as String,
    intercity: {
      for (final e in (json['intercity'] as Map<String, Object?>).entries)
        e.key: {
          for (final m in (e.value as Map<String, Object?>).entries)
            IntercityMode.values.byName(m.key): IntercityOption.fromJson(
              m.value as Map<String, Object?>,
            ),
        },
    },
  );

  final String id;
  final String name;
  final GeoPoint center;
  final String regionTag;

  /// Highlights used when ranking Destination Suggestions.
  final List<PreferenceTag> tags;

  /// One rating per month, January first.
  final List<SeasonRating> seasonality;
  final String seasonNote;

  /// Ways to get here, keyed by the Origin province id. A trip that starts
  /// in this province has no entry and costs nothing to reach.
  final Map<String, Map<IntercityMode, IntercityOption>> intercity;

  SeasonRating seasonFor(int month) => seasonality[month - 1];

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'center': center.toJson(),
    'regionTag': regionTag,
    'tags': [for (final t in tags) t.name],
    'seasonality': [for (final s in seasonality) s.name],
    'seasonNote': seasonNote,
    'intercity': {
      for (final e in intercity.entries)
        e.key: {for (final m in e.value.entries) m.key.name: m.value.toJson()},
    },
  };
}

/// One way to travel between an Origin and this province, one direction.
final class IntercityOption {
  const IntercityOption({
    required this.durationMin,
    this.farePerPerson = 0,
    this.distanceKm,
    this.toll = 0,
  });

  factory IntercityOption.fromJson(Map<String, Object?> json) =>
      IntercityOption(
        durationMin: (json['durationMin'] as num).toInt(),
        farePerPerson: (json['farePerPerson'] as num?)?.toInt() ?? 0,
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        toll: (json['toll'] as num?)?.toInt() ?? 0,
      );

  final int durationMin;

  /// Ticket price per person (bus, train). Zero when driving.
  final int farePerPerson;

  /// Road distance, used when driving.
  final double? distanceKm;

  /// Flat expressway toll per car, used when driving.
  final int toll;

  Map<String, Object?> toJson() => {
    'durationMin': durationMin,
    if (farePerPerson != 0) 'farePerPerson': farePerPerson,
    if (distanceKm != null) 'distanceKm': distanceKm,
    if (toll != 0) 'toll': toll,
  };
}
