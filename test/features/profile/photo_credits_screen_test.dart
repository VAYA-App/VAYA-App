import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/data/photo_catalog.dart';
import 'package:vaya_app/features/profile/photo_credits_screen.dart';

PhotoCredit _credit(String id, String author) => PhotoCredit(
  id: id,
  title: 'photo of $id',
  author: author,
  licence: 'CC BY-SA 4.0',
  source: 'https://commons.wikimedia.org/wiki/File:$id.jpg',
);

void main() {
  testWidgets('lists destinations, then places, then category photos', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        photoCatalogProvider.overrideWithValue(
          AsyncData(
            PhotoCatalog({
              for (final c in [
                _credit('category-restaurant', 'Takeaway'),
                _credit('chonburi-attraction-koh-larn', 'Supanut'),
                _credit('chonburi', 'Suicasmo'),
              ])
                c.id: c,
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(placeCatalogProvider.future));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PhotoCreditsScreen()),
      ),
    );
    await tester.pump();

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data)
        .toList();
    expect(titles, ['ชลบุรี', 'เกาะล้าน', 'ภาพประจำหมวดร้านอาหาร']);
    expect(
      find.text('“photo of chonburi” · Suicasmo · CC BY-SA 4.0'),
      findsOneWidget,
    );
  });
}
