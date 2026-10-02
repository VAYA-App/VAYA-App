import 'dart:convert';
import 'dart:io';

import 'package:vaya_app/domain/domain.dart';

/// Shared fixtures for planner tests.

Map<String, Object?> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// The bundled sample data, loaded without Flutter's asset bundle.
PlaceCatalog sampleCatalog() {
  final index = readJson('assets/data/provinces.json');
  final provinces = [
    for (final p in index['provinces'] as List)
      Province.fromJson(p as Map<String, Object?>),
  ];
  return PlaceCatalog(
    provinces: provinces,
    places: [
      for (final province in provinces)
        for (final p
            in readJson('assets/data/places/${province.id}.json')['places']
                as List)
          Place.fromJson({
            ...p as Map<String, Object?>,
            'provinceId': province.id,
          }),
    ],
  );
}

/// Bangkok → Chonburi, 2 days, 2 people, beach & cafe, chill (demo 1).
TripRequest demoRequest({
  int budget = 6000,
  int travellers = 2,
  Pace pace = Pace.chill,
  Set<PreferenceTag> tags = const {PreferenceTag.beach, PreferenceTag.cafe},
  DateTime? end,
  String note = '',
}) => TripRequest(
  startDate: DateTime(2026, 11, 14),
  endDate: end ?? DateTime(2026, 11, 15),
  travellerCount: travellers,
  budget: budget,
  originId: 'bangkok',
  destinationId: 'chonburi',
  intercityMode: IntercityMode.bus,
  localTransportMode: LocalTransportMode.taxi,
  preferenceTags: tags,
  pace: pace,
  note: note,
);
