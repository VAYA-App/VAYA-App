import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/features/explore/explore_screen.dart';
import 'package:vaya_app/features/explore/place_detail_screen.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';
import 'package:vaya_app/features/trip_request/trip_request_screen.dart';

void main() {
  Future<ProviderContainer> pumpExplore(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: MockAuthRepository.demoUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(photoCatalogProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    container.read(routerProvider).go(AppRoutes.explore);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('narrows places by search, then opens one to plan a trip', (
    tester,
  ) async {
    final c = await pumpExplore(tester);
    expect(find.text('พบ 120 สถานที่'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'เกาะล้าน');
    await tester.pumpAndSettle();
    expect(find.text('พบ 1 สถานที่'), findsOneWidget);

    await tester.tap(find.widgetWithText(PlaceTile, 'เกาะล้าน'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceDetailScreen), findsOneWidget);
    expect(find.text('ไม่มีค่าเข้า'), findsOneWidget);

    await tester.tap(find.text('วางแผนทริปชลบุรี'));
    await tester.pumpAndSettle();
    expect(find.byType(TripRequestScreen), findsOneWidget);
    expect(c.read(tripRequestFormProvider).destinationId, 'chonburi');
  });

  testWidgets('a province and a category combine', (tester) async {
    await pumpExplore(tester);

    await tester.tap(find.text('ชลบุรี').first);
    await tester.pumpAndSettle();
    expect(find.text('พบ 58 สถานที่'), findsOneWidget);

    await tester.tap(find.text('พัก'));
    await tester.pumpAndSettle();
    expect(find.text('พบ 9 สถานที่'), findsOneWidget);
  });
}
