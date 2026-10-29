import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

  test('Google Maps pins the coordinates and labels the pin with the name', () {
    final uri = placeMapUri(place, platform: TargetPlatform.android);
    expect(uri.scheme, 'https');
    expect(uri.host, 'maps.google.com');
    expect(uri.queryParameters['q'], '12.92,100.78(เกาะล้าน)');
  });

  test('Apple Maps on iOS shows the place name on the pin', () {
    final uri = placeMapUri(place, platform: TargetPlatform.iOS);
    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters, {'ll': '12.92,100.78', 'q': 'เกาะล้าน'});
  });

  group('tapping the button', () {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');

    /// Taps the button with [launch] answering the url_launcher plugin, and
    /// returns the URLs it was asked to open.
    Future<List<String>> tap(
      WidgetTester tester,
      Object? Function() launch,
    ) async {
      final opened = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        opened.add((call.arguments as Map)['url'] as String);
        return launch();
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OpenInMapsButton(place: place)),
        ),
      );
      await tester.tap(find.text('ดูบนแผนที่'));
      await tester.pump();
      return opened;
    }

    testWidgets('opens the place in the map app', (tester) async {
      final opened = await tap(tester, () => true);

      expect(opened, [placeMapUri(place).toString()]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('says so when no app can open it', (tester) async {
      await tap(tester, () => false);

      expect(find.text('เปิดแผนที่ไม่ได้'), findsOneWidget);
    });

    testWidgets('says so when opening it fails', (tester) async {
      await tap(tester, () => throw PlatformException(code: 'ERROR'));

      expect(find.text('เปิดแผนที่ไม่ได้'), findsOneWidget);
    });
  });
}
