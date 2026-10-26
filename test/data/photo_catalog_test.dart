import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/data/asset_place_catalog.dart';
import 'package:vaya_app/data/photo_catalog.dart';
import 'package:vaya_app/domain/domain.dart';

PhotoCredit _credit(String id) => PhotoCredit(
  id: id,
  title: id,
  author: 'someone',
  licence: 'CC BY-SA 4.0',
  source: 'https://commons.wikimedia.org/wiki/File:$id.jpg',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('assetFor', () {
    final catalog = PhotoCatalog({
      for (final id in ['koh-larn', 'category-restaurant']) id: _credit(id),
    });

    test('prefers the place\'s own photo', () {
      expect(
        catalog.assetFor('koh-larn', fallback: PlaceCategory.attraction),
        'assets/photos/koh-larn.webp',
      );
    });

    test('falls back to the category photo', () {
      expect(
        catalog.assetFor('some-cafe', fallback: PlaceCategory.restaurant),
        'assets/photos/category-restaurant.webp',
      );
      expect(catalog.hasOwnPhoto('some-cafe'), isFalse);
    });

    test('has nothing when neither exists', () {
      expect(
        catalog.assetFor('some-hotel', fallback: PlaceCategory.accommodation),
        isNull,
      );
      expect(catalog.assetFor('some-hotel'), isNull);
    });
  });

  group('bundled photos', () {
    late PhotoCatalog photos;
    late PlaceCatalog places;

    setUpAll(() async {
      photos = await loadPhotoCatalog(rootBundle);
      places = await loadPlaceCatalog(rootBundle);
    });

    test('every credit has a file and a source', () {
      for (final c in photos.credits.values) {
        expect(File(photoAsset(c.id)).existsSync(), isTrue, reason: c.id);
        expect(Uri.parse(c.source).isAbsolute, isTrue, reason: c.id);
      }
    });

    test('Commons photos carry a licence the app may use', () {
      final commons = photos.credits.values.where(
        (c) => c.source.startsWith('https://commons.wikimedia.org/'),
      );
      expect(commons, isNotEmpty);
      for (final c in commons) {
        expect(
          c.licence,
          anyOf(startsWith('CC0'), startsWith('CC BY'), startsWith('Public')),
          reason: c.id,
        );
        expect(c.licence, isNot(contains('NC')), reason: c.id);
        expect(c.licence, isNot(contains('ND')), reason: c.id);
      }
    });

    test('every file in assets/photos has a credit', () {
      final files = Directory('assets/photos')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.webp'))
          .map((f) => f.uri.pathSegments.last.replaceAll('.webp', ''));
      expect(files.toSet(), photos.credits.keys.toSet());
    });

    test('credits only name real places, destinations or categories', () {
      for (final id in photos.credits.keys) {
        final known =
            places.findPlace(id) != null ||
            places.findProvince(id) != null ||
            PlaceCategory.values.any((c) => PhotoCatalog.categoryId(c) == id);
        expect(known, isTrue, reason: id);
      }
    });

    test('every place has a photo of its own', () {
      for (final place in places.places) {
        expect(photos.hasOwnPhoto(place.id), isTrue, reason: place.id);
      }
    });

    test('every destination and category has a photo', () {
      for (final p in places.provinces) {
        expect(photos.hasOwnPhoto(p.id), isTrue, reason: p.id);
      }
      for (final c in PlaceCategory.values) {
        expect(photos.hasOwnPhoto(PhotoCatalog.categoryId(c)), isTrue);
      }
    });
  });
}
