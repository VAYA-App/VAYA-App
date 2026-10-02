import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/ai/prompts/select_places.dart';
import 'package:vaya_app/planner/candidate_builder.dart';
import 'package:vaya_app/planner/slot_template.dart';

import '../planner/test_data.dart';

void main() {
  final catalog = sampleCatalog();
  final request = demoRequest(note: 'ไปกับผู้สูงอายุ');
  final candidates = const CandidateBuilder().build(
    request: request,
    provinceId: 'chonburi',
    catalog: catalog,
  );
  final days = SlotTemplate.forTrip(request, intercityMinutes: 150);

  test('parses the recorded response shape', () {
    final selection = SelectPlacesPrompt.parse(
      readJson('test/fixtures/select_places_chonburi_2d.json'),
    );

    expect(selection.accommodationTier, 3);
    expect(selection.days.map((d) => d.map((p) => p.slot).toList()), [
      for (final d in days) d.slots,
    ]);
    expect(
      selection.days.first.first.note,
      'ปราสาทไม้ริมทะเล เหมาะกับสายถ่ายรูป',
    );
  });

  test('rejects malformed JSON with a FormatException', () {
    expect(
      () => SelectPlacesPrompt.parse({'accommodationTier': 2}),
      throwsFormatException,
    );
    expect(
      () => SelectPlacesPrompt.parse({
        'accommodationTier': 2,
        'days': [
          {
            'slots': [
              {'slot': 'brunch', 'placeId': 'x', 'note': ''},
            ],
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('the prompt carries the request, slots, note and candidates', () {
    final prompt = SelectPlacesPrompt.build(
      request: request,
      province: catalog.province('chonburi'),
      days: days,
      candidates: candidates,
    );

    expect(prompt, contains('Traveller note: ไปกับผู้สูงอายุ'));
    expect(prompt, contains('Day 2 (2026-11-15): morning, lunch, afternoon'));
    expect(prompt, contains('Pace: chill'));
    for (final p in candidates.attractions) {
      expect(prompt, contains(p.id));
    }
    expect(prompt, isNot(contains('rejected')));
  });

  test('a retry tells Gemini what was wrong', () {
    final prompt = SelectPlacesPrompt.build(
      request: request,
      province: catalog.province('chonburi'),
      days: days,
      candidates: candidates,
      previousErrors: const ['Day 1 lunch: unknown placeId "x"'],
    );
    expect(prompt, contains('- Day 1 lunch: unknown placeId "x"'));
  });

  test('schema limits slots to the known names', () {
    final slotSchema =
        (((SelectPlacesPrompt.responseSchema['properties'] as Map)['days']
                as Map)['items']
            as Map);
    expect(slotSchema.toString(), contains('morning'));
    expect(SelectPlacesPrompt.responseSchema['required'], [
      'days',
      'accommodationTier',
    ]);
  });
}
