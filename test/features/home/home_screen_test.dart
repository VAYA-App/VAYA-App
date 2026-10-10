import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/theme/theme_mode_provider.dart';
import 'package:vaya_app/data/mock/in_memory_trip_repository.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/data/trip_repository.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/home/greeting.dart';
import 'package:vaya_app/features/trip_plan/trip_plan_screen.dart';
import 'package:vaya_app/features/trip_request/trip_request_screen.dart';
import 'package:vaya_app/shared/widgets/mascot_view.dart';

Trip _createTrip({
  String id = 'trip-1',
  String destinationId = 'chonburi',
  DateTime? startDate,
  DateTime? endDate,
  int travellers = 2,
  int totalCost = 5640,
  int budget = 7000,
}) {
  final start = startDate ?? DateTime(2026, 11, 14);
  final end = endDate ?? DateTime(2026, 11, 15);
  return Trip(
    id: id,
    ownerUid: 'demo-user',
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
    request: TripRequest(
      startDate: start,
      endDate: end,
      travellerCount: travellers,
      budget: budget,
      originId: 'bangkok',
      destinationId: destinationId,
      localTransportMode: LocalTransportMode.rentalCar,
      preferenceTags: const {},
      pace: Pace.normal,
    ),
    plan: TripPlan(
      destinationId: destinationId,
      status: PlanStatus.ok,
      nightStays: const [],
      days: const [],
      cost: CostEstimate(
        intercity: 500,
        accommodation: 2000,
        food: 1500,
        entrance: 500,
        localTransport: 640,
        buffer: 500,
        total: totalCost,
        perPerson: (totalCost / travellers).round(),
        budget: budget,
      ),
    ),
  );
}

void main() {
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

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    int hour = 8,
    TripRepository? tripRepository,
    Size size = const Size(412, 900),
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = tripRepository ?? InMemoryTripRepository();
    final container = ProviderContainer(
      overrides: [
        greetingClockProvider.overrideWithValue(DateTime(2026, 10, 5, hour)),
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: MockAuthRepository.demoUser),
        ),
        tripRepositoryProvider.overrideWithValue(repo),
        themeModeProvider.overrideWith(() => _StaticThemeNotifier(themeMode)),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(placeCatalogProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the mascot waves next to the greeting', (tester) async {
    await pumpHome(tester, hour: 8);

    expect(find.text('สวัสดีตอนเช้า'), findsOneWidget);
    expect(
      tester.widget<MascotView>(find.byType(MascotView)).pose,
      MascotPose.wave,
    );
  });

  testWidgets('large text fits without the mascot', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHome(tester, hour: 20);

    expect(tester.takeException(), isNull);
    expect(find.text('สวัสดีตอนค่ำ'), findsOneWidget);
    expect(find.byType(MascotView), findsNothing);
  });

  testWidgets('the empty state starts a first trip', (tester) async {
    await pumpHome(tester, hour: 13);

    final start = find.text('เริ่มวางแผนทริปแรก');
    await tester.scrollUntilVisible(start, 200);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.byType(TripRequestScreen), findsOneWidget);
  });

  testWidgets('displays saved trips with province, dates, count, and cost', (
    tester,
  ) async {
    final repo = InMemoryTripRepository();
    await repo.saveTrip(
      _createTrip(destinationId: 'chonburi', totalCost: 5640),
    );

    await pumpHome(tester, tripRepository: repo);

    expect(find.text('ชลบุรี'), findsOneWidget);
    expect(find.text('14–15 พ.ย. · 2 คน'), findsOneWidget);
    expect(find.text('฿5,640'), findsOneWidget);
    expect(find.text('เกินงบ'), findsNothing);
  });

  testWidgets('shows over budget badge when total exceeds budget', (
    tester,
  ) async {
    final repo = InMemoryTripRepository();
    await repo.saveTrip(
      _createTrip(destinationId: 'chonburi', totalCost: 8500, budget: 6000),
    );

    await pumpHome(tester, tripRepository: repo);

    expect(find.text('ชลบุรี'), findsOneWidget);
    expect(find.text('เกินงบ'), findsOneWidget);
  });

  testWidgets('FAB opens the new trip screen', (tester) async {
    await pumpHome(tester);

    final fab = find.widgetWithText(FloatingActionButton, 'วางแผนทริปใหม่');
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.byType(TripRequestScreen), findsOneWidget);
  });

  testWidgets('swiping a trip deletes it and shows undo SnackBar', (
    tester,
  ) async {
    final repo = InMemoryTripRepository();
    await repo.saveTrip(_createTrip(id: 'chonburi-1'));

    await pumpHome(tester, tripRepository: repo);

    expect(find.text('ชลบุรี'), findsOneWidget);

    // Swipe from right to left to dismiss
    await tester.drag(find.text('ชลบุรี'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('ชลบุรี'), findsNothing);
    expect(await repo.getTrip('chonburi-1'), isNull);
    expect(find.text('ลบทริปชลบุรีแล้ว'), findsOneWidget);
    expect(find.text('เลิกทำ'), findsOneWidget);

    // Tap undo
    await tester.tap(find.text('เลิกทำ'));
    await tester.pumpAndSettle();

    expect(find.text('ชลบุรี'), findsOneWidget);
    expect(await repo.getTrip('chonburi-1'), isNotNull);
  });

  testWidgets('saving a new trip stream updates home screen live', (
    tester,
  ) async {
    final repo = InMemoryTripRepository();
    await pumpHome(tester, tripRepository: repo);

    expect(find.text('ยังไม่มีทริป'), findsOneWidget);
    expect(find.text('ชลบุรี'), findsNothing);

    await repo.saveTrip(_createTrip(destinationId: 'chonburi'));
    await tester.pumpAndSettle();

    expect(find.text('ชลบุรี'), findsOneWidget);
    expect(find.text('ยังไม่มีทริป'), findsNothing);
  });

  testWidgets('tapping a saved trip card opens the trip plan screen', (
    tester,
  ) async {
    final repo = InMemoryTripRepository();
    await repo.saveTrip(_createTrip(id: 'chonburi-1'));

    await pumpHome(tester, tripRepository: repo);

    final card = find.text('ชลบุรี');
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TripPlanScreen), findsOneWidget);
  });

  testWidgets('expanded window shows multi-column grid', (tester) async {
    final repo = InMemoryTripRepository();
    await repo.saveTrip(_createTrip(id: 't-1', destinationId: 'chonburi'));
    await repo.saveTrip(_createTrip(id: 't-2', destinationId: 'bangkok'));

    await pumpHome(tester, tripRepository: repo, size: const Size(1000, 800));

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('ชลบุรี'), findsOneWidget);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'narrow phone at 200% font scaling renders cleanly (${theme.name})',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final repo = InMemoryTripRepository();
        await repo.saveTrip(
          _createTrip(destinationId: 'chonburi', totalCost: 9000, budget: 6000),
        );

        await pumpHome(
          tester,
          tripRepository: repo,
          size: const Size(360, 800),
          themeMode: theme,
        );

        expect(tester.takeException(), isNull);
        final chonburi = find.text('ชลบุรี');
        await tester.scrollUntilVisible(chonburi, 300);
        expect(chonburi, findsOneWidget);
        expect(find.text('เกินงบ'), findsOneWidget);
      },
    );
  }
}

class _StaticThemeNotifier extends ThemeModeNotifier {
  _StaticThemeNotifier(this._mode);
  final ThemeMode _mode;

  @override
  ThemeMode build() => _mode;
}
