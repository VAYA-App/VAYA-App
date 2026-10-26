import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/app/theme/theme_mode_provider.dart';
import 'package:vaya_app/data/mock/in_memory_trip_repository.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/home/greeting.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';

/// The day the trip tests run on: 2 Nov 2026, twelve days before the
/// default trip.
final testToday = DateTime(2026, 11, 2);

Trip createTrip({
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

/// The whole app, signed in, opened on [route].
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  String route = AppRoutes.home,
  List<Trip> trips = const [],
  InMemoryTripRepository? repository,
  int hour = 8,
  Size size = const Size(412, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = repository ?? InMemoryTripRepository();
  for (final t in trips) {
    await repo.saveTrip(t);
  }
  final container = ProviderContainer(
    overrides: [
      greetingClockProvider.overrideWithValue(DateTime(2026, 11, 2, hour)),
      todayProvider.overrideWithValue(testToday),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: MockAuthRepository.demoUser),
      ),
      tripRepositoryProvider.overrideWithValue(repo),
      themeModeProvider.overrideWith(() => _StaticThemeNotifier(themeMode)),
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
  container.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  return container;
}

class _StaticThemeNotifier extends ThemeModeNotifier {
  _StaticThemeNotifier(this._mode);
  final ThemeMode _mode;

  @override
  ThemeMode build() => _mode;
}
