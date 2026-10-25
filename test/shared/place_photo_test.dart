import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/data/photo_catalog.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/shared/widgets/place_photo.dart';

void main() {
  final catalog = PhotoCatalog({
    for (final id in ['koh-larn', 'category-restaurant'])
      id: PhotoCredit(
        id: id,
        title: id,
        author: 'someone',
        licence: 'CC0',
        source: 'https://commons.wikimedia.org/wiki/File:$id.jpg',
      ),
  });

  Future<void> pump(WidgetTester tester, Widget photo) => tester.pumpWidget(
    ProviderScope(
      overrides: [photoCatalogProvider.overrideWithValue(AsyncData(catalog))],
      child: MaterialApp(
        home: Center(child: SizedBox(width: 160, height: 120, child: photo)),
      ),
    ),
  );

  String? assetOf(WidgetTester tester) {
    final images = tester.widgetList<Image>(find.byType(Image));
    if (images.isEmpty) return null;
    final provider = images.single.image;
    final key = provider is ResizeImage ? provider.imageProvider : provider;
    return (key as AssetImage).assetName;
  }

  testWidgets('shows the place\'s own photo, named for screen readers', (
    tester,
  ) async {
    await pump(
      tester,
      const PlacePhoto(id: 'koh-larn', label: 'เกาะล้าน', heroTag: 'k'),
    );
    expect(assetOf(tester), 'assets/photos/koh-larn.webp');
    expect(find.bySemanticsLabel('เกาะล้าน'), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets('falls back to the category photo', (tester) async {
    await pump(
      tester,
      const PlacePhoto(
        id: 'a-cafe',
        label: 'ร้านกาแฟ',
        category: PlaceCategory.restaurant,
      ),
    );
    expect(assetOf(tester), 'assets/photos/category-restaurant.webp');
  });

  testWidgets('shows a tint when there is no photo at all', (tester) async {
    await pump(tester, const PlacePhoto(id: 'a-hotel', label: 'โรงแรม'));
    expect(assetOf(tester), isNull);
    expect(find.bySemanticsLabel('โรงแรม'), findsOneWidget);
  });
}
