import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gemini_service.dart';

/// Gemini through the Gemini Developer API with an API key, until Firebase
/// AI Logic is set up (#26, #144). The key ships inside the app, so use a
/// key restricted to this API and never commit it.
///
/// Built to survive a bad day at Google: it walks [models] in order, retries
/// the temporary failures (5xx, timeouts, no network) once per model, moves
/// on at once from a model out of quota, retired or not allowed, treats
/// blocked or cut-off answers as a failure of that model, and gives up within
/// [deadline] so the caller's fallback runs before the user gives up.
/// Callers retry a rejected answer once, so one step waits at most about
/// twice [deadline]. After an outage it stays quiet for [coolDown] so every
/// screen does not wait again; a prompt that only got bad answers does not.
class RestGeminiService implements GeminiService {
  RestGeminiService(
    this._client, {
    required this.apiKey,
    this.model = defaultModel,
    List<String> fallbackModels = defaultFallbackModels,
    this.timeout = const Duration(seconds: 20),
    this.deadline = const Duration(seconds: 25),
    this.retryDelay = const Duration(milliseconds: 600),
    this.coolDown = const Duration(seconds: 30),
    Uri? server,
    DateTime Function()? now,
  }) : models = _distinct([model, ...fallbackModels]),
       _server =
           server ?? Uri.parse('https://generativelanguage.googleapis.com'),
       _now = now ?? DateTime.now;

  static const defaultModel = 'gemini-flash-latest';

  /// Different model families, so one retired or overloaded model does not
  /// take the others down with it.
  static const defaultFallbackModels = [
    'gemini-flash-lite-latest',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
  ];

  final http.Client _client;
  final String apiKey;
  final String model;

  /// [model] first, then the fallbacks, without repeats or blanks.
  final List<String> models;

  /// For one request.
  final Duration timeout;

  /// For the whole call, all models and retries together.
  final Duration deadline;
  final Duration retryDelay;
  final Duration coolDown;
  final Uri _server;
  final DateTime Function() _now;

  DateTime? _quietUntil;
  GeminiException? _lastFailure;

  static List<String> _distinct(List<String> names) => {
    for (final n in names)
      if (n.trim().isNotEmpty) n.trim(),
  }.toList();

  @override
  Future<Map<String, Object?>> generateJson({
    required String systemInstruction,
    required String prompt,
    required Map<String, Object?> responseSchema,
  }) async {
    final quietUntil = _quietUntil;
    if (quietUntil != null && _now().isBefore(quietUntil)) {
      throw _lastFailure ?? const GeminiException('Gemini is unavailable');
    }

    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': responseSchema,
      },
    });

    final clock = Stopwatch()..start();
    GeminiException? failure;
    // Only an outage (network, quota, server, key) silences later calls; a
    // prompt that gets unusable answers says nothing about the other prompts.
    var outage = true;
    for (final name in models) {
      for (var attempt = 0; attempt < 2; attempt++) {
        if (clock.elapsed >= deadline) {
          return _giveUp(
            failure ?? const GeminiException('Gemini took too long'),
            quiet: outage,
          );
        }
        try {
          return await _ask(name, body, _remaining(clock));
        } on _Attempt catch (e) {
          failure = e.failure;
          outage = outage && e.outage;
          if (e.then == _Then.stop) return _giveUp(failure, quiet: true);
          if (e.then == _Then.nextModel) break;
          if (attempt == 0) {
            final wait = _remaining(clock);
            await Future<void>.delayed(wait < retryDelay ? wait : retryDelay);
          }
        }
      }
    }
    return _giveUp(
      failure ?? const GeminiException('No Gemini model to ask'),
      quiet: outage,
    );
  }

  Duration _remaining(Stopwatch clock) {
    final left = deadline - clock.elapsed;
    if (left.isNegative) return Duration.zero;
    return left < timeout ? left : timeout;
  }

  Never _giveUp(GeminiException failure, {required bool quiet}) {
    if (quiet) {
      _lastFailure = failure;
      _quietUntil = _now().add(coolDown);
    }
    throw failure;
  }

  Future<Map<String, Object?>> _ask(
    String name,
    String body,
    Duration limit,
  ) async {
    // Abortable, so a request we stop waiting for does not keep running and
    // use up data and quota in the background.
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            'POST',
            _server.replace(path: '/v1beta/models/$name:generateContent'),
            abortTrigger: abort.future,
          )
          ..headers.addAll({
            'content-type': 'application/json',
            'x-goog-api-key': apiKey,
          })
          ..body = body;
    final http.Response response;
    try {
      response = await () async {
        return http.Response.fromStream(await _client.send(request));
      }().timeout(limit);
    } on TimeoutException catch (e) {
      if (!abort.isCompleted) abort.complete();
      throw _Attempt(
        GeminiException('Gemini took too long ($name)', cause: e),
        then: _Then.sameModel,
        outage: true,
      );
    } on Object catch (e) {
      throw _Attempt(
        GeminiException('Gemini could not be reached ($name)', cause: e),
        then: _Then.sameModel,
        outage: true,
      );
    }

    final status = response.statusCode;
    if (status != 200) {
      final failure = GeminiException('Gemini answered $status ($name)');
      // The key or the API is refused, so every other model says the same.
      if (status == 401 || _keyRejected(response.body)) {
        throw _Attempt(failure, then: _Then.stop, outage: true);
      }
      // Each model has its own quota, so asking this one again in a moment
      // only spends what is left; another model may still have room.
      if (status == 429) {
        throw _Attempt(failure, then: _Then.nextModel, outage: true);
      }
      // Temporary: worth asking the same model again.
      if (status == 408 || status >= 500) {
        throw _Attempt(failure, then: _Then.sameModel, outage: true);
      }
      // 404 retired model, 403 a model this key may not use: try the next.
      if (status == 403 || status == 404) {
        throw _Attempt(failure, then: _Then.nextModel, outage: true);
      }
      // 400 and the rest: this request did not suit that model.
      throw _Attempt(failure, then: _Then.nextModel, outage: false);
    }

    try {
      return _parse(response.body);
    } on GeminiException catch (e) {
      // Blocked, cut off or not JSON: another model may do better.
      throw _Attempt(e, then: _Then.nextModel, outage: false);
    } on Object catch (e) {
      // Any shape we did not expect is still only a bad answer.
      throw _Attempt(
        GeminiException('Gemini returned no usable JSON', cause: e),
        then: _Then.nextModel,
        outage: false,
      );
    }
  }

  /// Reasons Google gives when the key, not the model, is the problem.
  static const _keyProblems = [
    'API_KEY_INVALID',
    'API key not valid',
    'API_KEY_SERVICE_BLOCKED',
    'API_KEY_HTTP_REFERRER_BLOCKED',
    'API_KEY_ANDROID_APP_BLOCKED',
    'API_KEY_IOS_APP_BLOCKED',
    'SERVICE_DISABLED',
  ];

  static bool _keyRejected(String body) => _keyProblems.any(body.contains);

  static Map<String, Object?> _parse(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException catch (e) {
      throw GeminiException('Gemini returned no usable JSON', cause: e);
    }
    if (json is! Map) {
      throw const GeminiException('Gemini returned no usable JSON');
    }
    if (json['promptFeedback'] case {'blockReason': final blocked?}) {
      throw GeminiException('Gemini blocked the request ($blocked)');
    }
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
      throw const GeminiException('Gemini returned no answer');
    }
    final candidate = candidates.first as Map;
    final finish = candidate['finishReason'];
    if (finish != null && finish != 'STOP') {
      // MAX_TOKENS cuts the JSON short; SAFETY and the rest give no answer.
      throw GeminiException('Gemini stopped early ($finish)');
    }
    final parts = switch (candidate['content']) {
      {'parts': final List parts} => parts,
      _ => null,
    };
    if (parts == null) {
      throw const GeminiException('Gemini returned no answer');
    }
    final text = [
      for (final p in parts)
        if (p is Map && p['thought'] != true && p['text'] is String)
          p['text'] as String,
    ].join();
    final Object? answer;
    try {
      answer = jsonDecode(_unfence(text));
    } on FormatException catch (e) {
      throw GeminiException('Gemini returned no usable JSON', cause: e);
    }
    if (answer is! Map) {
      throw const GeminiException('Gemini returned no usable JSON');
    }
    return answer.cast<String, Object?>();
  }

  /// Models sometimes wrap JSON in a ```json fence even when told not to.
  static String _unfence(String text) {
    final trimmed = text.trim();
    final fenced = RegExp(
      r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$',
    ).firstMatch(trimmed);
    return fenced?.group(1) ?? trimmed;
  }
}

/// What to ask after a failed attempt.
enum _Then {
  /// Temporary trouble: the same model may answer a moment later.
  sameModel,
  nextModel,

  /// No model can help, such as a rejected key.
  stop,
}

/// One failed ask, and what to do about it.
class _Attempt implements Exception {
  const _Attempt(this.failure, {required this.then, required this.outage});

  final GeminiException failure;
  final _Then then;

  /// Gemini or the network is down, as opposed to a bad answer to this
  /// prompt.
  final bool outage;
}
