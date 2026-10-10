import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/ai/mock_gemini_service.dart';
import 'package:vaya_app/ai/prompts/select_places.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/candidate_builder.dart';
import 'package:vaya_app/planner/fallback_scorer.dart';
import 'package:vaya_app/planner/place_selection.dart';
import 'package:vaya_app/planner/place_selector.dart';
import 'package:vaya_app/planner/plan_validator.dart';
import 'package:vaya_app/planner/route_orderer.dart';
import 'package:vaya_app/planner/slot_template.dart';

import 'test_data.dart';

void main() {
  final catalog = sampleCatalog();
  final province = catalog.province('chonburi');
  final request = demoRequest();
  final candidates = const CandidateBuilder().build(
    request: request,
    provinceId: 'chonburi',
    catalog: catalog,
  );
  final days = SlotTemplate.forTrip(request, intercityMinutes: 150);
  final fixture = readJson('test/fixtures/select_places_chonburi_2d.json');
  const validator = PlanValidator();

  PlaceSelection withDay1(List<SlotPick> day1) {
    final good = SelectPlacesPrompt.parse(fixture);
    return PlaceSelection(
      days: [day1, good.days[1]],
      accommodationTier: good.accommodationTier,
    );
  }

  List<SlotPick> day1Of(PlaceSelection s) => [...s.days.first];

  group('PlanValidator', () {
    test('accepts the fixture', () {
      expect(
        validator.validate(SelectPlacesPrompt.parse(fixture), days, candidates),
        isEmpty,
      );
    });

    test('catches an invented place id', () {
      final day1 = day1Of(SelectPlacesPrompt.parse(fixture))
        ..[0] = const SlotPick(
          slot: Slot.morning,
          placeId: 'chonburi-attraction-made-up',
        );
      expect(validator.validate(withDay1(day1), days, candidates), [
        'Day 1 morning: unknown placeId "chonburi-attraction-made-up"',
      ]);
    });

    test('catches a place used twice', () {
      final good = SelectPlacesPrompt.parse(fixture);
      final day1 = day1Of(
        good,
      )..[2] = SlotPick(slot: Slot.afternoon, placeId: good.days[0][0].placeId);
      expect(
        validator.validate(withDay1(day1), days, candidates),
        contains(contains('used more than once')),
      );
    });

    test('catches a restaurant in an attraction slot', () {
      final day1 = day1Of(SelectPlacesPrompt.parse(fixture))
        ..[0] = const SlotPick(
          slot: Slot.morning,
          placeId: 'chonburi-restaurant-lan-pho-naklua',
        );
      expect(
        validator.validate(withDay1(day1), days, candidates),
        contains(
          'Day 1 morning: "chonburi-restaurant-lan-pho-naklua" is a restaurant, expected a attraction',
        ),
      );
    });

    test('catches missing slots and days and a bad tier', () {
      final good = SelectPlacesPrompt.parse(fixture);
      final errors = validator.validate(
        PlaceSelection(
          days: [good.days[0].sublist(0, 2)],
          accommodationTier: 7,
        ),
        days,
        candidates,
      );
      expect(
        errors,
        containsAll([
          'accommodationTier must be 1-4, got 7',
          'Expected 2 days, got 1',
          contains('Day 1: expected slots'),
        ]),
      );
    });
  });

  group('FallbackScorer', () {
    test('fills every slot with valid, distinct places', () {
      final s = const FallbackScorer().select(
        request: request,
        days: days,
        candidates: candidates,
      );
      expect(validator.validate(s, days, candidates), isEmpty);
      expect(s.accommodationTier, CandidateBuilder.priceCap(request));
    });

    test('still fills every slot when slots outnumber candidates', () {
      final long = demoRequest(pace: Pace.packed, end: DateTime(2026, 11, 20));
      final longDays = SlotTemplate.forTrip(long);
      final c = const CandidateBuilder().build(
        request: long,
        provinceId: 'chonburi',
        catalog: catalog,
      );
      final s = const FallbackScorer().select(
        request: long,
        days: longDays,
        candidates: c,
      );

      for (final (i, d) in longDays.indexed) {
        expect(s.days[i].map((p) => p.slot), d.slots);
      }
    });

    test('prefers places matching the traveller tags', () {
      final s = const FallbackScorer().select(
        request: request,
        days: days,
        candidates: candidates,
      );
      final first = catalog.place(s.days.first.first.placeId);
      expect(
        first.tags.toSet().intersection(request.preferenceTags),
        isNotEmpty,
      );
      expect(s.days.first.first.note, startsWith('ตรงกับสไตล์'));
    });
  });

  group('PlaceSelector', () {
    Future<({PlaceSelection selection, SelectionSource source})> selectWith(
      MockGeminiResponder? responder,
    ) => PlaceSelector(gemini: MockGeminiService(responder: responder)).select(
      request: request,
      province: province,
      days: days,
      candidates: candidates,
    );

    test('uses Gemini when its answer is valid', () async {
      final r = await selectWith((_, _) => fixture);
      expect(r.source, SelectionSource.gemini);
      expect(r.selection.accommodationTier, 2);
    });

    test('falls back when Gemini is unavailable', () async {
      final r = await selectWith(null);
      expect(r.source, SelectionSource.fallback);
      expect(validator.validate(r.selection, days, candidates), isEmpty);
    });

    test(
      'retries once with the problems, then accepts a fixed answer',
      () async {
        final prompts = <String>[];
        final r = await selectWith((_, prompt) {
          prompts.add(prompt);
          return prompts.length == 1
              ? {'days': [], 'accommodationTier': 3}
              : fixture;
        });

        expect(r.source, SelectionSource.gemini);
        expect(prompts, hasLength(2));
        expect(prompts.last, contains('Expected 2 days, got 0'));
      },
    );

    test('falls back after two bad answers', () async {
      var calls = 0;
      final r = await selectWith((_, _) {
        calls++;
        return {'nonsense': true};
      });
      expect(calls, 2);
      expect(r.source, SelectionSource.fallback);
    });
  });
}
