import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/domain.dart';

const provincesAsset = 'assets/data/provinces.json';
String placesAsset(String provinceId) => 'assets/data/places/$provinceId.json';

/// Loads the bundled data described in docs/DATA.md (ADR-0002).
/// Adding a province only needs a new entry in `provinces.json` and a
/// matching `places/<id>.json`; no code changes.
Future<PlaceCatalog> loadPlaceCatalog(AssetBundle bundle) async {
  final index =
      jsonDecode(await bundle.loadString(provincesAsset))
          as Map<String, Object?>;
  final provinces = [
    for (final p in index['provinces'] as List)
      Province.fromJson(p as Map<String, Object?>),
  ];

  final places = <Place>[];
  for (final province in provinces) {
    final file =
        jsonDecode(await bundle.loadString(placesAsset(province.id)))
            as Map<String, Object?>;
    for (final p in file['places'] as List) {
      places.add(
        Place.fromJson({
          ...p as Map<String, Object?>,
          'provinceId': province.id,
        }),
      );
    }
  }
  return PlaceCatalog(provinces: provinces, places: places);
}
