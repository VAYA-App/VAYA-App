import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/candidate_builder.dart';

import 'test_data.dart';

Place place(
  String id,
  PlaceCategory category, {
  int level = 1,
  double rating = 4,
  List<PreferenceTag> tags = const [],
}) => Place(
  id: id,
  provinceId: 'p',
  category: category,
  name: id,
  location: const GeoPoint(13, 100),
  tags: tags,
  priceLevel: level,
  rating: rating,
  shortDescription: id,
);

void main() {
  const builder = CandidateBuilder();
  final catalog = PlaceCatalog(
    provinces: const [],
    places: [
      place('plain', PlaceCategory.attraction, rating: 4.9),
      place(
        'beach',
        PlaceCategory.attraction,
        rating: 4.0,
        tags: const [PreferenceTag.beach],
      ),
      place(
        'pricey',
        PlaceCategory.attraction,
        level: 4,
        tags: const [PreferenceTag.beach],
      ),
      place('food', PlaceCategory.restaurant),
      place('lux-hotel', PlaceCategory.accommodation, level: 4),
      place('mid-hotel', PlaceCategory.accommodation, level: 3),
    ],
  );

  Candidates build({int budget = 2000}) => builder.build(
    request: demoRequest(budget: budget),
    provinceId: 'p',
    catalog: catalog,
  );

  test('price cap follows spend per person per day', () {
    expect(CandidateBuilder.priceCap(demoRequest(budget: 2000)), 1); // 500
    expect(CandidateBuilder.priceCap(demoRequest(budget: 4000)), 2); // 1,000
    expect(CandidateBuilder.priceCap(demoRequest(budget: 8000)), 3); // 2,000
    expect(CandidateBuilder.priceCap(demoRequest(budget: 20000)), 4); // 5,000
  });

  test('drops places above the cap and ranks tag matches first', () {
    expect(build().attractions.map((p) => p.id), ['beach', 'plain']);
  });

  test('keeps the cheapest level when nothing is affordable', () {
    expect(build().accommodations.map((p) => p.id), ['mid-hotel']);
  });

  test('excludes disliked places', () {
    final c = builder.build(
      request: demoRequest(budget: 2000),
      provinceId: 'p',
      catalog: catalog,
      excludedPlaceIds: {'beach'},
    );
    expect(c.attractions.map((p) => p.id), ['plain']);
  });

  test('looks places up by id', () {
    final c = build();
    expect(c.find('food')?.category, PlaceCategory.restaurant);
    expect(c.find('pricey'), isNull);
  });

  test('works on the bundled Chonburi data', () {
    final c = builder.build(
      request: demoRequest(),
      provinceId: 'chonburi',
      catalog: sampleCatalog(),
    );
    expect(c.attractions, isNotEmpty);
    expect(c.restaurants, isNotEmpty);
    expect(c.accommodations, isNotEmpty);
    expect(c.all.length, lessThanOrEqualTo(80));
  });
}
