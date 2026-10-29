import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';

/// Rough bounding box of each province, to catch swapped or mistyped
/// coordinates.
const _bounds = {
  'bangkok': (minLat: 13.49, maxLat: 13.96, minLng: 100.32, maxLng: 100.94),
  'chonburi': (minLat: 12.50, maxLat: 13.60, minLng: 100.70, maxLng: 101.60),
  'chiang-mai': (minLat: 17.24, maxLat: 20.15, minLng: 98.00, maxLng: 99.58),
  'ayutthaya': (minLat: 14.10, maxLat: 14.68, minLng: 100.21, maxLng: 100.83),
  'phuket': (minLat: 7.26, maxLat: 8.21, minLng: 98.06, maxLng: 98.50),
  'krabi': (minLat: 7.07, maxLat: 8.69, minLng: 98.59, maxLng: 99.42),
  'kanchanaburi': (minLat: 13.72, maxLat: 15.67, minLng: 98.18, maxLng: 99.88),
  'prachuap-khiri-khan': (
    minLat: 10.95,
    maxLat: 12.67,
    minLng: 99.14,
    maxLng: 100.46,
  ),
};

/// Minimum Attractions, Restaurants and Accommodations per province (#21,
/// #22).
const _minimum = {
  PlaceCategory.attraction: 25,
  PlaceCategory.restaurant: 20,
  PlaceCategory.accommodation: 8,
};

/// Checks the raw JSON, since `PlaceCatalog` keeps only the last place of a
/// repeated id without complaint.
void main() {
  for (final provinceId in _bounds.keys) {
    group(provinceId, () {
      final json = jsonDecode(
        File('assets/data/places/$provinceId.json').readAsStringSync(),
      );
      final places = [
        for (final p in (json as Map)['places'] as List)
          p as Map<String, Object?>,
      ];
      PlaceCategory category(Map<String, Object?> p) =>
          PlaceCategory.values.byName(p['category']! as String);

      test('every id is unique', () {
        final ids = places.map((p) => p['id']).toList();
        expect(ids.toSet(), hasLength(ids.length));
      });

      test('has the minimum number of places per category', () {
        for (final MapEntry(key: wanted, value: minimum) in _minimum.entries) {
          expect(
            places.where((p) => category(p) == wanted),
            hasLength(greaterThanOrEqualTo(minimum)),
            reason: wanted.name,
          );
        }
      });

      test('accommodations cover every price level', () {
        expect(
          {
            for (final p in places)
              if (category(p) == PlaceCategory.accommodation) p['priceLevel'],
          },
          {1, 2, 3, 4},
        );
      });

      test('every tag is a Preference Tag', () {
        final allowed = PreferenceTag.values.map((t) => t.name).toSet();
        for (final p in places) {
          expect(
            allowed.containsAll(p['tags']! as List),
            isTrue,
            reason: '${p['id']}',
          );
        }
      });

      test('every place lies inside the province', () {
        final b = _bounds[provinceId]!;
        for (final p in places) {
          final location = p['location']! as Map;
          expect(
            location['lat'],
            inInclusiveRange(b.minLat, b.maxLat),
            reason: '${p['id']}',
          );
          expect(
            location['lng'],
            inInclusiveRange(b.minLng, b.maxLng),
            reason: '${p['id']}',
          );
        }
      });

      test('descriptions are at most 120 characters', () {
        for (final p in places) {
          expect(
            (p['shortDescription']! as String).length,
            lessThanOrEqualTo(120),
            reason: '${p['id']}',
          );
        }
      });

      test('no opening period closes before it opens', () {
        for (final p in places) {
          final hours = p['openingHours'] as Map? ?? const {};
          for (final MapEntry(key: day, value: period) in hours.entries) {
            final [open as String, close as String] = period as List;
            // "HH:mm" strings sort like times.
            expect(
              close.compareTo(open),
              greaterThan(0),
              reason: '${p['id']} $day',
            );
          }
        }
      });
    });
  }
}
