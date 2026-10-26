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
  RestGeminiService service(
    MockClientHandler handler, {
    DateTime Function()? now,
    Duration deadline = const Duration(seconds: 45),
  }) => RestGeminiService(
    MockClient(handler),
    apiKey: 'test-key',
    retryDelay: Duration.zero,
    deadline: deadline,
    now: now,
  );

  http.Response ok([Object json = const {'provinces': <Object>[]}]) =>
      http.Response(
        _answer(json),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  String modelOf(http.Request r) =>
      r.url.pathSegments.last.replaceAll(':generateContent', '');

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
        retryDelay: Duration.zero,
      ).generateJson(
        systemInstruction: '',
        prompt: '',
        responseSchema: const {},
      ),
      throwsA(isA<GeminiException>()),
    );
  });

  group('when Gemini has a bad day', () {
    test('asks the same model again after a 503, then succeeds', () async {
      final asked = <String>[];
      final json = await ask(
        service((request) async {
          asked.add(modelOf(request));
          return asked.length == 1 ? http.Response('busy', 503) : ok();
        }),
      );
      expect(json, {'provinces': <Object>[]});
      expect(asked, ['gemini-flash-latest', 'gemini-flash-latest']);
    });

    test('moves to the next model when one keeps failing', () async {
      final asked = <String>[];
      final json = await ask(
        service((request) async {
          asked.add(modelOf(request));
          return modelOf(request) == 'gemini-flash-lite-latest'
              ? ok()
              : http.Response('busy', 503);
        }),
      );
      expect(json, {'provinces': <Object>[]});
      expect(asked, [
        'gemini-flash-latest',
        'gemini-flash-latest',
        'gemini-flash-lite-latest',
      ]);
    });

    test('a retired model (404) goes straight to the next one', () async {
      final asked = <String>[];
      await ask(
        service((request) async {
          asked.add(modelOf(request));
          return asked.length == 1 ? http.Response('gone', 404) : ok();
        }),
      );
      expect(asked, ['gemini-flash-latest', 'gemini-flash-lite-latest']);
    });

    test('a rejected key stops at once, not after every model', () async {
      for (final rejection in [
        http.Response(
          '{"error":{"status":"PERMISSION_DENIED",'
          '"details":[{"reason":"SERVICE_DISABLED"}]}}',
          403,
        ),
        http.Response(
          '{"error":{"details":[{"reason":"API_KEY_ANDROID_APP_BLOCKED"}]}}',
          403,
        ),
        http.Response('nope', 401),
        http.Response(
          '{"error":{"details":[{"reason":"API_KEY_INVALID"}]}}',
          400,
        ),
      ]) {
        var calls = 0;
        await expectLater(
          ask(
            service((_) async {
              calls++;
              return rejection;
            }),
          ),
          throwsA(isA<GeminiException>()),
        );
        expect(calls, 1, reason: '${rejection.statusCode}');
      }
    });

    test('a 403 for one model only moves on to the next model', () async {
      final asked = <String>[];
      final json = await ask(
        service((request) async {
          asked.add(modelOf(request));
          return asked.length == 1
              ? http.Response('{"error":{"status":"PERMISSION_DENIED"}}', 403)
              : ok();
        }),
      );
      expect(json, {'provinces': <Object>[]});
      expect(asked, ['gemini-flash-latest', 'gemini-flash-lite-latest']);
    });

    test(
      'out of quota (429) moves on without asking that model again',
      () async {
        final asked = <String>[];
        final json = await ask(
          service((request) async {
            asked.add(modelOf(request));
            return asked.length == 1 ? http.Response('quota', 429) : ok();
          }),
        );
        expect(json, {'provinces': <Object>[]});
        expect(asked, ['gemini-flash-latest', 'gemini-flash-lite-latest']);
      },
    );

    test('an answer of an unexpected shape is a GeminiException', () async {
      for (final body in [
        {
          'candidates': [
            {'content': 'not a map'},
          ],
        },
        {
          'candidates': [
            {
              'content': {'parts': 'not a list'},
            },
          ],
        },
        {'promptFeedback': 'not a map'},
        {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '{"provinces":[]}'},
                ],
              },
            },
          ],
          'promptFeedback': <Object>[],
        },
      ]) {
        final result = ask(
          service((_) async => http.Response(jsonEncode(body), 200)),
        );
        if (body.containsKey('candidates') && body['promptFeedback'] is List) {
          // Odd feedback alone does not spoil a good answer.
          expect(await result, {'provinces': <Object>[]});
        } else {
          await expectLater(result, throwsA(isA<GeminiException>()));
        }
      }
    });

    test('bad answers to one prompt do not silence the others', () async {
      var time = DateTime(2026, 10, 26, 12);
      var answerWell = false;
      final gemini = service((_) async {
        return answerWell
            ? ok()
            : http.Response(
                jsonEncode({
                  'promptFeedback': {'blockReason': 'SAFETY'},
                }),
                200,
              );
      }, now: () => time);

      await expectLater(ask(gemini), throwsA(isA<GeminiException>()));
      answerWell = true;
      // No time passes: an outage would still be in its cool-down here.
      expect(await ask(gemini), {'provinces': <Object>[]});
    });

    test('waiting to retry never runs past the deadline', () async {
      final clock = Stopwatch()..start();
      await expectLater(
        RestGeminiService(
          MockClient((_) async => http.Response('busy', 503)),
          apiKey: 'k',
          deadline: const Duration(milliseconds: 100),
          retryDelay: const Duration(seconds: 10),
        ).generateJson(
          systemInstruction: '',
          prompt: '',
          responseSchema: const {},
        ),
        throwsA(isA<GeminiException>()),
      );
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test(
      'an unusable answer fails that model, the next may do better',
      () async {
        final unusable = <String, String>{
          'blocked prompt': jsonEncode({
            'promptFeedback': {'blockReason': 'SAFETY'},
          }),
          'no candidates': jsonEncode({'candidates': <Object>[]}),
          'cut off': jsonEncode({
            'candidates': [
              {
                'finishReason': 'MAX_TOKENS',
                'content': {
                  'parts': [
                    {'text': '{"provinces":['},
                  ],
                },
              },
            ],
          }),
          'safety stop, no content': jsonEncode({
            'candidates': [
              {'finishReason': 'SAFETY'},
            ],
          }),
          'empty parts': jsonEncode({
            'candidates': [
              {
                'content': {'parts': <Object>[]},
              },
            ],
          }),
          'text is not json': jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'sorry, I cannot'},
                  ],
                },
              },
            ],
          }),
          'a list instead of an object': _answer(<Object>[1, 2]),
          'body is not json': '<html>proxy error</html>',
          'body is a list': '[]',
        };
        for (final entry in unusable.entries) {
          final asked = <String>[];
          final json = await ask(
            service((request) async {
              asked.add(modelOf(request));
              return asked.length == 1
                  ? http.Response(entry.value, 200)
                  : ok({'second': 'model'});
            }),
          );
          expect(json, {'second': 'model'}, reason: entry.key);
          expect(asked.length, 2, reason: entry.key);
        }
      },
    );

    test('reads a code-fenced answer and skips thought parts', () async {
      final json = await ask(
        service(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {'text': 'let me think', 'thought': true},
                      {'text': '```json\n{"provinces": []}\n```'},
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

    test('a dropped connection is retried and then falls back', () async {
      final asked = <String>[];
      final json = await ask(
        service((request) async {
          asked.add(modelOf(request));
          if (asked.length < 3) throw http.ClientException('connection reset');
          return ok();
        }),
      );
      expect(json, {'provinces': <Object>[]});
      expect(asked.length, 3);
    });

    test('tries every model, then throws GeminiException', () async {
      final asked = <String>{};
      await expectLater(
        ask(
          service((request) async {
            asked.add(modelOf(request));
            return http.Response('busy', 503);
          }),
        ),
        throwsA(isA<GeminiException>()),
      );
      expect(asked, {
        'gemini-flash-latest',
        'gemini-3.5-flash',
        'gemini-flash-lite-latest',
        'gemini-3.1-flash-lite',
      });
    });

    test('gives up within the deadline instead of hanging', () async {
      final clock = Stopwatch()..start();
      await expectLater(
        ask(
          service(
            (_) => Future.delayed(
              const Duration(milliseconds: 200),
              () => http.Response('busy', 503),
            ),
            deadline: const Duration(milliseconds: 250),
          ),
        ),
        throwsA(isA<GeminiException>()),
      );
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('stays quiet for a while after a total failure', () async {
      var time = DateTime(2026, 10, 26, 12);
      var calls = 0;
      final gemini = service((_) async {
        calls++;
        return http.Response('busy', 503);
      }, now: () => time);

      await expectLater(ask(gemini), throwsA(isA<GeminiException>()));
      final first = calls;
      await expectLater(ask(gemini), throwsA(isA<GeminiException>()));
      expect(calls, first, reason: 'no new request during the cool-down');

      time = time.add(const Duration(seconds: 31));
      await expectLater(ask(gemini), throwsA(isA<GeminiException>()));
      expect(calls, greaterThan(first), reason: 'asks again once it is over');
    });
  });

  test('the model list has no blanks or repeats', () {
    final gemini = RestGeminiService(
      MockClient((_) async => ok()),
      apiKey: 'k',
      model: 'a',
      fallbackModels: const ['a', ' ', 'b', 'b'],
    );
    expect(gemini.models, ['a', 'b']);
  });
}
