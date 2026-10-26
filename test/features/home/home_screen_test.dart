import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/data/asset_place_catalog.dart';
import 'package:vaya_app/data/photo_catalog.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/home/greeting.dart';
import 'package:vaya_app/features/home/place_picks.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_screen.dart';
import 'package:vaya_app/features/trip_request/trip_request_screen.dart';
import 'package:vaya_app/planner/taste_profile.dart';
import 'package:vaya_app/shared/widgets/mascot_view.dart';
import 'package:vaya_app/shared/widgets/place_photo.dart';

import '../trips/trip_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('greets by the time of day', () {
    String title(int hour) => greetingFor(DateTime(2026, 10, 5, hour)).title;

    expect(title(5), 'สวัสดีตอนเช้า');
    expect(title(10), 'สวัสดีตอนเช้า');
    expect(title(11), 'สวัสดีตอนกลางวัน');
    expect(title(16), 'สวัสดีตอนเย็น');
    expect(title(19), 'สวัสดีตอนค่ำ');
    expect(title(23), 'สวัสดีตอนค่ำ');
    expect(title(0), 'ดึกแล้วนะ');
    expect(title(4), 'ดึกแล้วนะ');
  });

  testWidgets('the mascot waves next to the greeting', (tester) async {
    await pumpApp(tester, hour: 8);

    expect(find.text('สวัสดีตอนเช้า'), findsOneWidget);
    expect(
      tester.widget<MascotView>(find.byType(MascotView)).pose,
      MascotPose.wave,
    );
  });

  testWidgets('large text fits without the mascot', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, hour: 20);

    expect(tester.takeException(), isNull);
    expect(find.text('สวัสดีตอนค่ำ'), findsOneWidget);
    expect(find.byType(MascotView), findsNothing);
  });

  testWidgets('without a trip ahead, planning is the way in', (tester) async {
    await pumpApp(
      tester,
      trips: [
        createTrip(
          startDate: DateTime(2026, 9, 5),
          endDate: DateTime(2026, 9, 6),
        ),
      ],
    );

    expect(find.text('ทริปถัดไป'), findsNothing);
    await tester.tap(find.text('วางแผนทริปใหม่'));
    await tester.pumpAndSettle();
    expect(find.byType(TripRequestScreen), findsOneWidget);
  });

  testWidgets('the upcoming trip counts down and opens its plan', (
    tester,
  ) async {
    await pumpApp(
      tester,
      trips: [
        createTrip(
          id: 'later',
          destinationId: 'bangkok',
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 1),
        ),
        createTrip(id: 'next'),
      ],
    );

    expect(find.text('ทริปถัดไป'), findsOneWidget);
    expect(find.text('อีก 12 วัน'), findsOneWidget);
    expect(find.text('ชลบุรี 2 วัน 1 คืน'), findsOneWidget);
    expect(find.text('14–15 พ.ย. · 2 คน · ฿5,640'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is PlacePhoto && w.id == 'chonburi'),
      findsOneWidget,
    );

    await tester.tap(find.text('ชลบุรี 2 วัน 1 คืน'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TripPlanScreen), findsOneWidget);
  });

  group('pickPlaces', () {
    late PlaceCatalog places;
    late PhotoCatalog photos;

    setUpAll(() async {
      places = await loadPlaceCatalog(rootBundle);
      photos = await loadPhotoCatalog(rootBundle);
    });

    test('suggests attractions with photos, never disliked ones', () {
      final noFeedback = pickPlaces(places, const TasteProfile(), photos);
      expect(noFeedback, isNotEmpty);
      expect(
        noFeedback.every((p) => p.category == PlaceCategory.attraction),
        isTrue,
      );
      expect(noFeedback.every((p) => photos.hasOwnPhoto(p.id)), isTrue);

      final top = noFeedback.first;
      final picks = pickPlaces(
        places,
        TasteProfile({top.id: PlaceFeedback.dislike}),
        photos,
      );
      expect(picks.map((p) => p.id), isNot(contains(top.id)));
    });

    test('follows what the traveller liked', () {
      final beach = places.places.firstWhere(
        (p) => p.tags.contains(PreferenceTag.beach),
      );
      final picks = pickPlaces(
        places,
        TasteProfile({beach.id: PlaceFeedback.like}),
        photos,
        limit: 3,
      );
      expect(
        picks.every((p) => p.tags.any((t) => beach.tags.contains(t))),
        isTrue,
      );
    });
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(360, 800), const Size(1000, 800)]) {
      testWidgets(
        '${size.width.round()}px at 200% text renders cleanly (${theme.name})',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpApp(
            tester,
            trips: [createTrip(totalCost: 9000, budget: 6000)],
            size: size,
            themeMode: theme,
          );

          expect(tester.takeException(), isNull);
          expect(find.text('ชลบุรี 2 วัน 1 คืน'), findsOneWidget);
        },
      );
    }
  }
}
