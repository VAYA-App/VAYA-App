import 'enums.dart';
import 'place.dart';
import 'province.dart';

/// Every supported Province and Place, loaded once at start-up.
/// See `lib/data/asset_place_catalog.dart` and docs/DATA.md.
final class PlaceCatalog {
  PlaceCatalog({required List<Province> provinces, required List<Place> places})
    : provinces = List.unmodifiable(provinces),
      _provincesById = {for (final p in provinces) p.id: p},
      _placesById = {for (final p in places) p.id: p};

  final List<Province> provinces;
  final Map<String, Province> _provincesById;
  final Map<String, Place> _placesById;

  Iterable<Place> get places => _placesById.values;

  Province? findProvince(String id) => _provincesById[id];

  Province province(String id) =>
      _provincesById[id] ?? (throw StateError('Unknown province "$id"'));

  bool contains(String placeId) => _placesById.containsKey(placeId);

  Place? findPlace(String id) => _placesById[id];

  Place place(String id) =>
      _placesById[id] ?? (throw StateError('Unknown place "$id"'));

  List<Place> placesIn(String provinceId, {PlaceCategory? category}) => [
    for (final p in _placesById.values)
      if (p.provinceId == provinceId &&
          (category == null || p.category == category))
        p,
  ];
}
