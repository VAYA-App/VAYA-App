import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:vaya_app/ai/gemini_service.dart';
import 'package:vaya_app/ai/prompts/rank_provinces.dart';
import 'package:vaya_app/ai/rest_gemini_service.dart';

/// Talks to the real Gemini from the phone, so it needs the key:
/// `flutter test integration_test/gemini_live_test.dart -d DEVICE_ID
/// --dart-define-from-file=env.json`. Without a key it is skipped.
const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const patient = Timeout(Duration(minutes: 5));

  Future<Map<String, Object?>> ask(RestGeminiService gemini) =>
      gemini.generateJson(
        systemInstruction: RankProvincesPrompt.systemInstruction,
        prompt:
            'Traveller: likes sea and cafes, 2 days. Candidates: '
            '[{"provinceId":"chonburi","tags":["sea","cafe"]}]',
        responseSchema: RankProvincesPrompt.responseSchema,
      );

  final skip = _apiKey.isEmpty ? 'GEMINI_API_KEY was not given' : null;

  // Google answers 503 now and then, so each model is tried by itself with
  // no fallback and the test only needs most of them to answer.
  test(
    'each model in the list can answer on its own',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final answered = <String>[];
      final failed = <String>[];
      for (final name in [
        RestGeminiService.defaultModel,
        ...RestGeminiService.defaultFallbackModels,
      ]) {
        try {
          final json = await ask(
            RestGeminiService(
              client,
              apiKey: _apiKey,
              model: name,
              fallbackModels: const [],
            ),
          );
          expect(json, contains('provinces'), reason: name);
          answered.add(name);
        } on GeminiException catch (e) {
          failed.add('$name: ${e.message} ${e.cause}');
        }
      }
      // ignore: avoid_print
      print('GEMINI answered: $answered failed: $failed');
      expect(answered, isNotEmpty, reason: 'every model failed: $failed');
    },
    skip: skip,
    timeout: patient,
  );

  test(
    'the service with fallbacks answers',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final json = await ask(RestGeminiService(client, apiKey: _apiKey));
      expect(json['provinces'], isA<List<Object?>>());
    },
    skip: skip,
    timeout: patient,
  );

  test('a wrong key fails fast with GeminiException, no hang', () async {
    final client = http.Client();
    addTearDown(client.close);
    final clock = Stopwatch()..start();
    await expectLater(
      ask(RestGeminiService(client, apiKey: 'not-a-real-key')),
      throwsA(isA<GeminiException>()),
    );
    expect(clock.elapsed, lessThan(const Duration(seconds: 15)));
  });

  test(
    'an unknown first model falls back to a working one',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final json = await ask(
        RestGeminiService(
          client,
          apiKey: _apiKey,
          model: 'gemini-does-not-exist',
        ),
      );
      expect(json['provinces'], isA<List<Object?>>());
    },
    skip: skip,
    timeout: patient,
  );
}
