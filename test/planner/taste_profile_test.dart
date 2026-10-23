import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/ai/gemini_service.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/default_cost_calculator.dart';
import 'package:vaya_app/planner/default_over_budget_advisor.dart';
import 'package:vaya_app/planner/default_planner_service.dart';
import 'package:vaya_app/planner/place_selector.dart';
import 'package:vaya_app/planner/taste_profile.dart';

import 'test_data.dart';

/// Records the prompt and fails, so the planner uses the fallback scorer.
class _OfflineGemini implements GeminiService {
  final prompts = <String>[];

  @override
  Future<Map<String, Object?>> generateJson({
    required String systemInstruction,
    required String prompt,
    required Map<String, Object?> responseSchema,
  }) async {
    prompts.add(prompt);
    throw const GeminiException('offline');
  }
}

void main() {
  final catalog = sampleCatalog();
  const calculator = DefaultCostCalculator(section9Pricing);
  const sanctuary = 'chonburi-attraction-sanctuary-of-truth';

  Future<(TripPlan, List<String>)> plan(TasteProfile taste) async {
    final gemini = _OfflineGemini();
    final progress = await DefaultPlannerService(
      loadCatalog: () async => catalog,
      selector: PlaceSelector(gemini: gemini),
      costCalculator: calculator,
      overBudgetAdvisor: const DefaultOverBudgetAdvisor(calculator),
      loadTaste: () => taste,
    ).generate(request: demoRequest(), destinationId: 'chonburi').toList();
    return (progress.last.plan!, gemini.prompts);
  }

  Set<String> placesIn(TripPlan p) => {
    for (final d in p.days)
      for (final s in d.stops) s.placeId,
  };

  test('weighs tags by likes and dislikes', () {
    final taste = const TasteProfile()
        .withFeedback(sanctuary, PlaceFeedback.like)
        .withFeedback(
          'chonburi-attraction-pattaya-viewpoint',
          PlaceFeedback.dislike,
        );

    final weights = taste.tagWeights(catalog);
    expect(weights[PreferenceTag.artCulture], 1);
    expect(weights[PreferenceTag.templeHistory], 1);
    // Liked once and disliked once: no weight left.
    expect(weights.containsKey(PreferenceTag.viewpoint), isFalse);
    expect(taste.disliked, {'chonburi-attraction-pattaya-viewpoint'});

    final cleared = taste.withFeedback(sanctuary, null);
    expect(cleared.feedback.keys, ['chonburi-attraction-pattaya-viewpoint']);
  });

  test('a disliked place is never planned again', () async {
    final (before, _) = await plan(const TasteProfile());
    final picked = placesIn(before).first;

    final (after, _) = await plan(
      const TasteProfile().withFeedback(picked, PlaceFeedback.dislike),
    );
    expect(placesIn(after), isNot(contains(picked)));
  });

  test('liked tags reach Gemini and lift matching places', () async {
    final (neutral, _) = await plan(const TasteProfile());
    final liked = const TasteProfile()
        .withFeedback('chonburi-attraction-khao-chi-chan', PlaceFeedback.like)
        .withFeedback(sanctuary, PlaceFeedback.like);
    final (tasteful, prompts) = await plan(liked);

    expect(prompts.first, contains('Liked before: '));
    expect(prompts.first, contains('templeHistory'));
    int temples(TripPlan p) => placesIn(p)
        .where(
          (id) => catalog.place(id).tags.contains(PreferenceTag.templeHistory),
        )
        .length;
    expect(temples(tasteful), greaterThanOrEqualTo(temples(neutral)));
  });

  test('without feedback the prompt says nothing about taste', () async {
    final (_, prompts) = await plan(const TasteProfile());
    expect(prompts.first, isNot(contains('Liked before')));
    expect(prompts.first, isNot(contains('Disliked before')));
  });
}
