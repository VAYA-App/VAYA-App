import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/features/profile/profile_screen.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_screen.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_view_provider.dart';
import 'package:vaya_app/planner/taste_profile.dart';

import 'plan_sheet_helper.dart';

const _sanctuary = 'chonburi-attraction-sanctuary-of-truth';
const _viewpoint = 'chonburi-attraction-pattaya-viewpoint';

void main() {
  ProviderContainer signedIn() {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: MockAuthRepository.demoUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('thumbs on a stop set and clear the feedback', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
    final container = signedIn();
    await tester.runAsync(() async {
      await container.read(placeCatalogProvider.future);
      await container.read(tripPlanViewProvider(mockTripId).future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TripPlanScreen(tripId: mockTripId)),
      ),
    );
    await tester.pump();
    await openPlanSheet(tester);
    // The open sheet already shows the first stop.
    final stop = find.text('ปราสาทสัจธรรม').first;
    await tester.tap(stop);
    await tester.pumpAndSettle();
    PlaceFeedback? feedback() =>
        container.read(tasteProfileProvider).feedback[_sanctuary];

    expect(find.text('ชอบที่นี่ไหม?'), findsOneWidget);
    await tester.tap(find.byTooltip('ชอบ'));
    await tester.pump();
    expect(find.text('ชอบที่นี่ จะแนะนำที่แบบนี้มากขึ้น'), findsOneWidget);
    expect(feedback(), PlaceFeedback.like);

    await tester.tap(find.byTooltip('ไม่ชอบ'));
    await tester.pump();
    expect(feedback(), PlaceFeedback.dislike);

    await tester.tap(find.byTooltip('ไม่ชอบ'));
    await tester.pump();
    expect(feedback(), isNull);
  });

  testWidgets('the profile shows the taste and can clear it', (tester) async {
    final container = signedIn();
    await tester.runAsync(() => container.read(placeCatalogProvider.future));
    container.read(tasteProfileProvider.notifier)
      ..set(_sanctuary, PlaceFeedback.like)
      ..set(_viewpoint, PlaceFeedback.dislike);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ความชอบของคุณ'), findsOneWidget);
    expect(find.text('ศิลปะ/วัฒนธรรม'), findsOneWidget);
    expect(find.text('ไม่แนะนำอีก 1 แห่ง'), findsOneWidget);

    await tester.ensureVisible(find.text('ล้างความชอบ'));
    await tester.tap(find.text('ล้างความชอบ'));
    await tester.pumpAndSettle();
    expect(find.text('ความชอบของคุณ'), findsNothing);
  });

  group('kept in Hive', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('vaya_feedback_');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('survives a restart and clears', () async {
      Future<ProviderContainer> open() async {
        final box = await Hive.openBox<String>(TasteProfileNotifier.boxName);
        final c = ProviderContainer(
          overrides: [placeFeedbackBoxProvider.overrideWithValue(box)],
        );
        addTearDown(c.dispose);
        return c;
      }

      final first = await open();
      final taste = first.read(tasteProfileProvider.notifier);
      await taste.set(_sanctuary, PlaceFeedback.like);
      await taste.set(_viewpoint, PlaceFeedback.dislike);
      await taste.set(_viewpoint, null);
      await taste.set(_viewpoint, PlaceFeedback.dislike);
      await Hive.close();

      final second = await open();
      expect(second.read(tasteProfileProvider).feedback, {
        _sanctuary: PlaceFeedback.like,
        _viewpoint: PlaceFeedback.dislike,
      });

      await second.read(tasteProfileProvider.notifier).clear();
      await Hive.close();
      final third = await open();
      expect(third.read(tasteProfileProvider).isEmpty, isTrue);
    });
  });
}
