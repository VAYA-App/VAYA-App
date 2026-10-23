import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/mock_providers.dart';
import 'package:vaya_app/data/road_router.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/trip_plan/widgets/trip_map.dart';

/// Answers with [path], or `null` like when offline.
class _FakeRouter implements RoadRouter {
  _FakeRouter(this.path);

  final List<GeoPoint>? path;
  final asked = <List<GeoPoint>>[];

  @override
  Future<List<GeoPoint>?> route(List<GeoPoint> points) async {
    asked.add(points);
    return path;
  }
}

void main() {
  late PlaceCatalog catalog;
  late TripPlan plan;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    catalog = await container.read(placeCatalogProvider.future);
    plan = await container.read(mockTripPlanProvider.future);
  });

  Future<_FakeRouter> pumpMap(WidgetTester tester, List<GeoPoint>? path) async {
    final router = _FakeRouter(path);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [roadRouterProvider.overrideWithValue(router)],
        child: MaterialApp(
          home: Scaffold(
            body: TripMap(
              day: plan.days.first,
              catalog: catalog,
              nightStay: plan.nightStays.first,
              interactive: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  List<LatLng> drawn(WidgetTester tester) => tester
      .widget<PolylineLayer>(find.byType(PolylineLayer))
      .polylines
      .single
      .points;

  testWidgets('asks for the road through the stops, then the night stay', (
    tester,
  ) async {
    final router = await pumpMap(tester, null);

    expect(router.asked.single, [
      for (final stop in plan.days.first.stops)
        catalog.place(stop.placeId).location,
      catalog.place(plan.nightStays.first.placeId).location,
    ]);
  });

  testWidgets('draws the road path once it arrives', (tester) async {
    const path = [
      GeoPoint(12.97, 100.89),
      GeoPoint(12.96, 100.885),
      GeoPoint(12.95, 100.88),
    ];
    await pumpMap(tester, path);

    expect(drawn(tester), [for (final p in path) LatLng(p.lat, p.lng)]);
  });

  testWidgets('offline: straight lines between the pins', (tester) async {
    await pumpMap(tester, null);

    // Four stops plus the night stay.
    expect(drawn(tester), hasLength(plan.days.first.stops.length + 1));
  });
}
