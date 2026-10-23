import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vaya_app/ai/gemini_service.dart';
import 'package:vaya_app/ai/prompts/rank_provinces.dart';
import 'package:vaya_app/ai/rest_gemini_service.dart';

/// What `generateContent` returns around [json].
String _answer(Object json) => jsonEncode({
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {'text': jsonEncode(json)},
        ],
      },
      'finishReason': 'STOP',
    },
  ],
});

void main() {
  RestGeminiService service(MockClientHandler handler) =>
      RestGeminiService(MockClient(handler), apiKey: 'test-key');

  Future<Map<String, Object?>> ask(RestGeminiService gemini) =>
      gemini.generateJson(
        systemInstruction: RankProvincesPrompt.systemInstruction,
        prompt: 'Candidates: chonburi',
        responseSchema: RankProvincesPrompt.responseSchema,
      );

  test('sends the key in a header and the schema as JSON Schema', () async {
    late http.Request sent;
    final json = await ask(
      service((request) async {
        sent = request;
        return http.Response(
          _answer({'provinces': <Object>[]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    expect(json, {'provinces': <Object>[]});
    expect(sent.method, 'POST');
    expect(
      sent.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${RestGeminiService.defaultModel}:generateContent',
    );
    // Never in the URL, where it would end up in logs.
    expect(sent.url.queryParameters, isEmpty);
    expect(sent.headers['x-goog-api-key'], 'test-key');

    final body = jsonDecode(sent.body) as Map<String, Object?>;
    expect((body['systemInstruction']! as Map)['parts'], [
      {'text': RankProvincesPrompt.systemInstruction},
    ]);
    expect(((body['contents']! as List).single as Map)['parts'], [
      {'text': 'Candidates: chonburi'},
    ]);
    expect(body['generationConfig'], {
      'responseMimeType': 'application/json',
      'responseJsonSchema': RankProvincesPrompt.responseSchema,
    });
  });

  test('joins answers split over several parts', () async {
    final json = await ask(
      service(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"provinces":'},
                    {'text': '[]}'},
                  ],
                },
              },
            ],
          }),
          200,
        ),
      ),
    );
    expect(json, {'provinces': <Object>[]});
  });

  test('every failure becomes a GeminiException', () async {
    Future<void> expectFails(MockClientHandler handler) =>
        expectLater(ask(service(handler)), throwsA(isA<GeminiException>()));

    await expectFails((_) async => http.Response('quota', 429));
    await expectFails((_) async => http.Response('{"candidates":[]}', 200));
    await expectFails(
      (_) async => http.Response(_answer('not an object'), 200),
    );
    await expectFails((_) async => throw http.ClientException('offline'));
    await expectLater(
      RestGeminiService(
        MockClient(
          (_) => Future.delayed(
            const Duration(milliseconds: 50),
            () => http.Response(_answer({}), 200),
          ),
        ),
        apiKey: 'k',
        timeout: const Duration(milliseconds: 10),
      ).generateJson(
        systemInstruction: '',
        prompt: '',
        responseSchema: const {},
      ),
      throwsA(isA<GeminiException>()),
    );
  });
}
