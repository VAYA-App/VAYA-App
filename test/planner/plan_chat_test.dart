import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/ai/gemini_service.dart';
import 'package:vaya_app/ai/prompts/edit_plan.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/default_cost_calculator.dart';
import 'package:vaya_app/planner/default_over_budget_advisor.dart';
import 'package:vaya_app/planner/plan_chat.dart';
import 'package:vaya_app/planner/plan_editor.dart';

import 'test_data.dart';

/// Answers with [answers] in turn; `null` fails like offline.
class _ScriptedGemini implements GeminiService {
  _ScriptedGemini([this.answers = const []]);

  final List<Map<String, Object?>?> answers;
  final prompts = <String>[];

  @override
  Future<Map<String, Object?>> generateJson({
    required String systemInstruction,
    required String prompt,
    required Map<String, Object?> responseSchema,
  }) async {
    prompts.add(prompt);
    final answer = prompts.length <= answers.length
        ? answers[prompts.length - 1]
        : null;
    if (answer == null) throw const GeminiException('offline');
    return answer;
  }
}

void main() {
  final catalog = sampleCatalog();
  const calculator = DefaultCostCalculator(section9Pricing);
  const editor = PlanEditor(
    costCalculator: calculator,
    overBudgetAdvisor: DefaultOverBudgetAdvisor(calculator),
  );
  final request = demoRequest(budget: 7000);
  final plan = calculator.applyCosts(
    request: request,
    plan: TripPlan.fromJson(readJson('assets/mock/trip_plan_chonburi_2d.json')),
    catalog: catalog,
  );

  Future<PlanChatReply> ask(String message, [GeminiService? gemini]) =>
      PlanChat(
        gemini: gemini ?? _ScriptedGemini(),
        editor: editor,
      ).ask(message, plan: plan, request: request, catalog: catalog);

  int mealOn(int day) => plan.days[day].stops.indexWhere((s) => s.slot.isMeal);

  group('with Gemini', () {
    test('uses its reply and edits', () async {
      final reply = await ask(
        'ไม่อยากไปจุดแรก',
        _ScriptedGemini([
          {
            'reply': 'ลบจุดแรกให้ไหม?',
            'edits': [
              {'action': 'removeStop', 'day': 1, 'stop': 1},
            ],
          },
        ]),
      );

      expect(reply.text, 'ลบจุดแรกให้ไหม?');
      expect(reply.edits.single, isA<RemoveStop>());
      expect((reply.edits.single.day, reply.edits.single.index), (0, 0));
    });

    test('retries with the problem, then uses the fixed answer', () async {
      final gemini = _ScriptedGemini([
        {
          'reply': 'เปลี่ยนให้',
          'edits': [
            {
              'action': 'replaceStop',
              'day': 1,
              'stop': mealOn(0) + 1,
              'placeId': 'phuket-restaurant-somewhere',
            },
          ],
        },
        {'reply': 'อยากเปลี่ยนเป็นร้านแบบไหน?', 'edits': <Object>[]},
      ]);
      final reply = await ask('เปลี่ยนร้าน', gemini);

      expect(gemini.prompts, hasLength(2));
      expect(gemini.prompts.last, contains('does not fit the plan'));
      expect(reply.text, 'อยากเปลี่ยนเป็นร้านแบบไหน?');
      expect(reply.edits, isEmpty);
    });

    test('falls back to keywords after two bad answers', () async {
      final gemini = _ScriptedGemini([
        {'nonsense': true},
        {'reply': '', 'edits': <Object>[]},
      ]);
      final reply = await ask('ลบจุดที่ 2 วันที่ 1', gemini);

      expect(gemini.prompts, hasLength(2));
      expect(reply.edits.single, isA<RemoveStop>());
    });

    test('the prompt lists the plan and places not in it', () {
      final prompt = EditPlanPrompt.build(
        message: 'ขอคาเฟ่',
        plan: plan,
        request: request,
        catalog: catalog,
      );
      final used = plan.days.expand((d) => d.stops).map((s) => s.placeId);

      expect(prompt, contains('Day 1 (2026-11-14):'));
      expect(prompt, contains('Traveller message: ขอคาเฟ่'));
      final candidates = prompt.split('Candidates not in the plan').last;
      for (final id in used) {
        expect(candidates, isNot(contains('$id |')));
      }
      expect(candidates, isNot(contains('accommodation')));
      expect(candidates, contains('chonburi-restaurant-'));
    });
  });

  group('offline keywords', () {
    test('"วันที่ 2 ขอร้านอาหารทะเลแทน" swaps a meal for seafood', () async {
      final reply = await ask('วันที่ 2 ขอร้านอาหารทะเลแทน');

      final edit = reply.edits.single as ReplaceStop;
      expect(edit.day, 1);
      expect(plan.days[1].stops[edit.index].slot.isMeal, isTrue);
      final place = catalog.place(edit.placeId);
      expect(place.category, PlaceCategory.restaurant);
      expect(place.tags, contains(PreferenceTag.seafood));
      expect(reply.text, contains(place.name));
      // It fits the plan.
      editor.apply(edit, plan: plan, request: request, catalog: catalog);
    });

    test('"ลบจุดที่ 2 วันที่ 1" removes that stop', () async {
      final reply = await ask('ลบ จุดที่ 2 วันที่ 1');
      final edit = reply.edits.single as RemoveStop;
      expect((edit.day, edit.index), (0, 1));
      expect(
        reply.text,
        contains(catalog.place(plan.days[0].stops[1].placeId).name),
      );
    });

    test('a cafe instead of the first sight', () async {
      final reply = await ask('ขอที่เที่ยวสายคาเฟ่แทนจุดที่ 1 วันที่ 1');
      final edit = reply.edits.single as ReplaceStop;
      final place = catalog.place(edit.placeId);
      expect(place.category, PlaceCategory.attraction);
      expect(place.tags, contains(PreferenceTag.cafe));
    });

    test('unclear or out of range: asks again without edits', () async {
      expect((await ask('สวัสดี')).text, KeywordPlanChat.help);
      expect((await ask('สวัสดี')).edits, isEmpty);
      expect((await ask('ลบจุดที่ 1 วันที่ 5')).text, contains('มี 2 วัน'));
    });
  });
}
