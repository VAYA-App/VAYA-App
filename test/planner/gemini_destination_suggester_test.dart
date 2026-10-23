import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/ai/gemini_service.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/providers/planner_providers.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/cost_calculator.dart';
import 'package:vaya_app/planner/gemini_destination_suggester.dart';

/// Answers with [responses] in turn; `null` fails the call like offline.
class _ScriptedGemini implements GeminiService {
  _ScriptedGemini([this.responses = const []]);

  final List<Map<String, Object?>?> responses;
  final prompts = <String>[];

  @override
  Future<Map<String, Object?>> generateJson({
    required String systemInstruction,
    required String prompt,
    required Map<String, Object?> responseSchema,
  }) async {
    prompts.add(prompt);
    final response = prompts.length <= responses.length
        ? responses[prompts.length - 1]
        : null;
    if (response == null) throw const GeminiException('offline');
    return response;
  }
}

Map<String, Object?> _ranking(List<String> ids) => {
  'provinces': [
    for (final id in ids)
      {
        'provinceId': id,
        'reason': 'เหตุผลของ $id',
        'highlightTags': ['cafe'],
      },
  ],
};

/// Demo scenario 1 without a Destination: 2 days, 2 people, ฿6,000 from
/// Bangkok, beach and cafés.
TripRequest _demo1({int budget = 6000}) => TripRequest(
  startDate: DateTime(2026, 11, 14),
  endDate: DateTime(2026, 11, 15),
  travellerCount: 2,
  budget: budget,
  originId: 'bangkok',
  localTransportMode: LocalTransportMode.publicTransport,
  preferenceTags: const {PreferenceTag.beach, PreferenceTag.cafe},
  pace: Pace.chill,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaceCatalog catalog;
  late CostCalculator calculator;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    catalog = await container.read(placeCatalogProvider.future);
    calculator = await container.read(costCalculatorProvider.future);
  });

  GeminiDestinationSuggester suggester(GeminiService gemini) =>
      GeminiDestinationSuggester(
        gemini: gemini,
        loadCatalog: () async => catalog,
        loadCostCalculator: () async => calculator,
      );

  List<String> ids(List<DestinationSuggestion> s) => [
    for (final x in s) x.provinceId,
  ];

  test('offline: demo scenario 1 suggests Chonburi before Bangkok', () async {
    final gemini = _ScriptedGemini();
    final result = await suggester(gemini).suggest(_demo1());

    expect(ids(result), ['chonburi', 'bangkok']);
    expect(gemini.prompts, hasLength(1)); // no retry when offline
    expect(result.first.reason, contains('ทะเล'));
    expect(result.first.highlightTags.take(2), [
      PreferenceTag.beach,
      PreferenceTag.cafe,
    ]);
    for (final s in result) {
      expect(s.minimumCost, inInclusiveRange(1, 6000));
      expect(s.reason, isNotEmpty);
    }
  });

  test("uses Gemini's order and reasons", () async {
    final gemini = _ScriptedGemini([
      _ranking(['bangkok', 'chonburi']),
    ]);
    final result = await suggester(gemini).suggest(_demo1());

    expect(ids(result), ['bangkok', 'chonburi']);
    expect(result.first.reason, 'เหตุผลของ bangkok');
    expect(result.first.highlightTags, [PreferenceTag.cafe]);
  });

  test('retries once with the problems, then uses the fixed answer', () async {
    final gemini = _ScriptedGemini([
      _ranking(['phuket', 'chonburi']),
      _ranking(['chonburi', 'bangkok']),
    ]);
    final result = await suggester(gemini).suggest(_demo1());

    expect(gemini.prompts, hasLength(2));
    expect(gemini.prompts.last, contains('"phuket" is not one of the'));
    expect(result.first.reason, 'เหตุผลของ chonburi');
  });

  test('falls back after two bad answers', () async {
    final gemini = _ScriptedGemini([
      _ranking(['chonburi', 'chonburi']),
      {'unexpected': true},
    ]);
    final result = await suggester(gemini).suggest(_demo1());

    expect(gemini.prompts, hasLength(2));
    expect(ids(result), ['chonburi', 'bangkok']);
    expect(result.first.reason, isNot(startsWith('เหตุผลของ')));
  });

  test('a province Gemini left out still follows at the end', () async {
    final gemini = _ScriptedGemini([
      _ranking(['bangkok']),
    ]);
    final result = await suggester(gemini).suggest(_demo1());

    expect(ids(result), ['bangkok', 'chonburi']);
    expect(result.last.reason, isNotEmpty);
  });

  test('nothing fits a tiny budget, and Gemini is not asked', () async {
    final gemini = _ScriptedGemini();
    final result = await suggester(gemini).suggest(_demo1(budget: 100));

    expect(result, isEmpty);
    expect(gemini.prompts, isEmpty);
  });

  test('validate lists unknown, repeated and empty answers', () {
    final candidates = [
      (province: catalog.province('chonburi'), minimumCost: 4000),
    ];
    expect(GeminiDestinationSuggester.validate(const [], candidates), [
      'The list of provinces is empty.',
    ]);
    expect(
      GeminiDestinationSuggester.validate([
        (provinceId: 'chonburi', reason: 'ok', highlightTags: const []),
        (provinceId: 'chonburi', reason: '', highlightTags: const []),
      ], candidates),
      ['"chonburi" is listed twice.', '"chonburi" has no reason.'],
    );
  });

  test('the app provider suggests Chonburi first for demo 1', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final result = await container
        .read(destinationSuggesterProvider)
        .suggest(_demo1());

    expect(result.first.provinceId, 'chonburi');
  });
}
