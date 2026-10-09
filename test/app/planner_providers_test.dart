import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/app/providers/ai_providers.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/planner_providers.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/planner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Demo 1: Bangkok → Chonburi, 2 days, 2 people, ฿6,000.
  final demo1 = TripRequest(
    startDate: DateTime(2026, 11, 14),
    endDate: DateTime(2026, 11, 15),
    travellerCount: 2,
    budget: 6000,
    originId: 'bangkok',
    intercityMode: IntercityMode.bus,
    localTransportMode: LocalTransportMode.publicTransport,
    preferenceTags: const {PreferenceTag.beach, PreferenceTag.cafe},
    pace: Pace.chill,
  );

  test('the app plans with the real pipeline from the bundled data', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final catalog = await container.read(placeCatalogProvider.future);

    final watch = Stopwatch()..start();
    final progress = await container
        .read(plannerServiceProvider)
        .generate(request: demo1, destinationId: 'chonburi')
        .toList();
    watch.stop();

    expect(progress.map((p) => p.stage), PlanningStage.values);
    final plan = progress.last.plan!;
    expect(plan.destinationId, 'chonburi');
    expect(plan.days, hasLength(2));
    expect(plan.nightStays, hasLength(1));
    for (final stop in plan.days.expand((d) => d.stops)) {
      expect(catalog.findPlace(stop.placeId), isNotNull, reason: stop.placeId);
    }
    expect(plan.cost.total, greaterThan(0));
    expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
  });

  test('a Gemini failure still gives a plan from the fallback', () async {
    // The default Gemini is the offline mock, which fails every call.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container
          .read(geminiServiceProvider)
          .generateJson(systemInstruction: '', prompt: '', responseSchema: {}),
      throwsA(anything),
    );

    final done = await container
        .read(plannerServiceProvider)
        .generate(request: demo1, destinationId: 'chonburi')
        .last;

    expect(done.stage, PlanningStage.done);
    expect(done.plan!.days.expand((d) => d.stops), isNotEmpty);
  });
}
