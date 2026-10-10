import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/layout/window_size_class.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/features/explore/trip_ideas.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Asset loading needs real async; load what the tabs read first.
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(tripIdeasProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compact window shows a bottom navigation bar', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('expanded window shows a navigation rail', (tester) async {
    await pumpApp(tester, const Size(1000, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('สร้างทริป'));
    await tester.pumpAndSettle();
    expect(find.text('ขั้นที่ 1 จาก 4'), findsOneWidget);
  });

  testWidgets('bottom bar opens every tab', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    for (final tab in ['สำรวจ', 'AI ช่วยคิด', 'โปรไฟล์', 'ทริปของฉัน']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('new trip action opens the trip request screen', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    await tester.tap(find.text('สร้างทริป'));
    await tester.pumpAndSettle();

    expect(find.text('วางแผนทริปใหม่'), findsWidgets);
    expect(find.text('ขั้นที่ 1 จาก 4'), findsOneWidget);
  });

  test('window size classes follow the M3 breakpoints', () {
    expect(WindowSizeClass.fromWidth(599), WindowSizeClass.compact);
    expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
    expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
    expect(WindowSizeClass.fromWidth(1200), WindowSizeClass.large);
    expect(WindowSizeClass.fromWidth(1600), WindowSizeClass.extraLarge);
  });
}
