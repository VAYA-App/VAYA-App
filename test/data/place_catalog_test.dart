import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/data/asset_place_catalog.dart';
import 'package:vaya_app/domain/domain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaceCatalog catalog;

  setUpAll(() async {
    catalog = await loadPlaceCatalog(rootBundle);
  });

  test('loads Bangkok and Chonburi with places in every category', () {
    expect(catalog.provinces.map((p) => p.id), ['bangkok', 'chonburi']);
    for (final province in catalog.provinces) {
      expect(province.seasonality, hasLength(12));
      for (final category in PlaceCategory.values) {
        expect(
          catalog.placesIn(province.id, category: category),
          isNotEmpty,
          reason: '${province.id} has no ${category.name}',
        );
      }
    }
  });

  test('place ids follow <province>-<category>-<slug>', () {
    for (final place in catalog.places) {
      expect(
        place.id,
        startsWith('${place.provinceId}-${place.category.name}-'),
      );
    }
  });

  test('both provinces can be reached from each other', () {
    expect(
      catalog.province('chonburi').intercity['bangkok'],
      containsPair(IntercityMode.bus, isA<IntercityOption>()),
    );
    expect(
      catalog.province('bangkok').intercity['chonburi'],
      containsPair(IntercityMode.bus, isA<IntercityOption>()),
    );
  });

  test('every place in the mock plan exists in the catalog', () {
    final plan = TripPlan.fromJson(
      jsonDecode(
            File('assets/mock/trip_plan_chonburi_2d.json').readAsStringSync(),
          )
          as Map<String, Object?>,
    );
    final ids = [
      ...plan.nightStays.map((n) => n.placeId),
      ...plan.days.expand((d) => d.stops).map((s) => s.placeId),
    ];

    for (final id in ids) {
      expect(catalog.contains(id), isTrue, reason: id);
    }
  });
}
