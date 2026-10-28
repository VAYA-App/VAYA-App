import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/shared/widgets/open_in_maps_button.dart';

void main() {
  const place = Place(
    id: 'chonburi-attraction-koh-larn',
    provinceId: 'chonburi',
    category: PlaceCategory.attraction,
    name: 'เกาะล้าน',
    location: GeoPoint(12.92, 100.78),
    tags: [],
    priceLevel: 1,
    shortDescription: '',
  );

  test('Google Maps puts the pin on the coordinates', () {
    final uri = placeMapUri(place, platform: TargetPlatform.android);
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['query'], '12.92,100.78');
  });

  test('Apple Maps on iOS shows the place name on the pin', () {
    final uri = placeMapUri(place, platform: TargetPlatform.iOS);
    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters, {'ll': '12.92,100.78', 'q': 'เกาะล้าน'});
  });
}
