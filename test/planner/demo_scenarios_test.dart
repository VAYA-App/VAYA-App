import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/app/providers/ai_providers.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/planner_providers.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/planner_service.dart';

import 'fixture_gemini.dart';
import 'test_data.dart';

/// The three demo scenarios (README, docs/SPRINT-2W.md) run through the app's
/// real pipeline and bundled data. Only Gemini is replaced, by recorded
/// answers, so every run gives the same plan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaceCatalog catalog;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    catalog = await container.read(placeCatalogProvider.future);
  });

  Future<TripPlan> plan(
    TripRequest request, {
    required String destinationId,
    required FixtureGemini gemini,
  }) async {
    final container = ProviderContainer(
      overrides: [geminiServiceProvider.overrideWithValue(gemini)],
    );
    addTearDown(container.dispose);
    final progress = await container
        .read(plannerServiceProvider)
        .generate(request: request, destinationId: destinationId)
        .toList();
    expect(progress.map((p) => p.stage), PlanningStage.values);
    return progress.last.plan!;
  }

  Set<String> pickedIn(String fixture) => {
    for (final day in readJson(fixture)['days'] as List)
      for (final slot in (day as Map)['slots'] as List)
        (slot as Map)['placeId'] as String,
  };

  void expectRealPlacesIn(TripPlan plan, String provinceId) {
    for (final stop in plan.days.expand((d) => d.stops)) {
      expect(
        catalog.findPlace(stop.placeId)?.provinceId,
        provinceId,
        reason: stop.placeId,
      );
    }
    for (final stay in plan.nightStays) {
      expect(
        catalog.findPlace(stay.placeId)?.category,
        PlaceCategory.accommodation,
        reason: stay.placeId,
      );
    }
  }

  group('demo 1: Bangkok → Chonburi, 2 days, ฿6,000, 2 people', () {
    const fixture = 'test/fixtures/select_places_chonburi_2d.json';
    final request = TripRequest(
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

    test('plans Pattaya and Bang Saen from the Gemini picks', () async {
      final gemini = FixtureGemini(fixture);
      final result = await plan(
        request,
        destinationId: 'chonburi',
        gemini: gemini,
      );

      expect(gemini.prompts, hasLength(1), reason: 'the answer was valid');
      expect({
        for (final s in result.days.expand((d) => d.stops)) s.placeId,
      }, pickedIn(fixture));
      expectRealPlacesIn(result, 'chonburi');
      expect(result.days, hasLength(2));
      expect(result.nightStays, hasLength(1));
      expect(result.intercity?.mode, IntercityMode.bus);
      expect(result.cost.intercity, greaterThan(0));
    });

    test(
      'fits the budget',
      () async {
        final result = await plan(
          request,
          destinationId: 'chonburi',
          gemini: FixtureGemini(fixture),
        );

        expect(result.status, PlanStatus.ok);
        expect(result.cost.total, lessThanOrEqualTo(request.budget));
        expect(result.overBudgetAdvice, isEmpty);
      },
      skip:
          'Chonburi has no Price Level 2 hotel yet, so the cheapest stay is '
          '฿3,000 and the plan costs ฿6,516. Unskip when #22 adds one.',
    );
  });

  group('demo 2: a temple day in Bangkok, ฿1,500, 1 person', () {
    const fixture = 'test/fixtures/select_places_bangkok_1d.json';
    final request = TripRequest(
      startDate: DateTime(2026, 11, 14),
      endDate: DateTime(2026, 11, 14),
      travellerCount: 1,
      budget: 1500,
      originId: 'bangkok',
      localTransportMode: LocalTransportMode.publicTransport,
      preferenceTags: const {PreferenceTag.templeHistory},
      pace: Pace.normal,
    );

    test('has no intercity leg or hotel and fits the budget', () async {
      final gemini = FixtureGemini(fixture);
      final result = await plan(
        request,
        destinationId: 'bangkok',
        gemini: gemini,
      );

      expect(gemini.prompts, hasLength(1), reason: 'the answer was valid');
      expect({
        for (final s in result.days.single.stops) s.placeId,
      }, pickedIn(fixture));
      expectRealPlacesIn(result, 'bangkok');
      expect(result.intercity, isNull);
      expect(result.cost.intercity, 0);
      expect(result.nightStays, isEmpty);
      expect(result.status, PlanStatus.ok);
      expect(result.cost.total, lessThanOrEqualTo(request.budget));
    });
  });

  group('demo 3: Chonburi, 3 days, ฿3,000, 4 people', () {
    final request = TripRequest(
      startDate: DateTime(2026, 11, 14),
      endDate: DateTime(2026, 11, 16),
      travellerCount: 4,
      budget: 3000,
      originId: 'bangkok',
      intercityMode: IntercityMode.bus,
      localTransportMode: LocalTransportMode.taxi,
      preferenceTags: const {PreferenceTag.beach, PreferenceTag.seafood},
      pace: Pace.chill,
    );

    // Also rehearses the demo with Gemini down (#44): no fixture, so the
    // pipeline uses the fallback scorer.
    test('is over budget with two or three pieces of advice', () async {
      final gemini = FixtureGemini();
      final result = await plan(
        request,
        destinationId: 'chonburi',
        gemini: gemini,
      );

      expect(gemini.prompts, hasLength(1), reason: 'no retry when offline');
      expectRealPlacesIn(result, 'chonburi');
      expect(result.days, hasLength(3));
      expect(result.nightStays, hasLength(2));
      expect(result.status, PlanStatus.overBudget);
      expect(result.cost.total, greaterThan(request.budget));
      expect(result.overBudgetAdvice, hasLength(inInclusiveRange(2, 3)));
      for (final advice in result.overBudgetAdvice) {
        expect(advice.saving, greaterThan(0), reason: advice.description);
      }
    });
  });
}
