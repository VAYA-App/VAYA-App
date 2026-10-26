import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gemini_service.dart';

/// Gemini through the Gemini Developer API with an API key, until Firebase
/// AI Logic is set up (#26, #144). The key ships inside the app, so use a
/// key restricted to this API and never commit it.
///
/// Built to survive a bad day at Google: it walks [models] in order, retries
/// the temporary failures (429, 5xx, timeouts, no network) once per model,
/// treats blocked or cut-off answers as a failure of that model, and gives up
/// within [deadline] so the caller's fallback runs before the user gives up.
/// After a total failure it stays quiet for [coolDown] so a long outage does
/// not make every screen wait again.
class RestGeminiService implements GeminiService {
  RestGeminiService(
    this._client, {
    required this.apiKey,
    this.model = defaultModel,
    List<String> fallbackModels = defaultFallbackModels,
    this.timeout = const Duration(seconds: 20),
    this.deadline = const Duration(seconds: 45),
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
    for (final name in models) {
      for (var attempt = 0; attempt < 2; attempt++) {
        if (clock.elapsed >= deadline) {
          return _giveUp(
            failure ?? const GeminiException('Gemini took too long'),
          );
        }
        try {
          return await _ask(name, body, _remaining(clock));
        } on _Attempt catch (e) {
          failure = e.failure;
          if (e.fatal) return _giveUp(failure);
          if (!e.retrySameModel) break;
          if (attempt == 0) await Future<void>.delayed(retryDelay);
        }
      }
    }
    return _giveUp(failure ?? const GeminiException('No Gemini model to ask'));
  }

  Duration _remaining(Stopwatch clock) {
    final left = deadline - clock.elapsed;
    return left < timeout ? left : timeout;
  }

  Never _giveUp(GeminiException failure) {
    _lastFailure = failure;
    _quietUntil = _now().add(coolDown);
    throw failure;
  }

  Future<Map<String, Object?>> _ask(
    String name,
    String body,
    Duration limit,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _server.replace(path: '/v1beta/models/$name:generateContent'),
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: body,
          )
          .timeout(limit);
    } on TimeoutException catch (e) {
      throw _Attempt(
        GeminiException('Gemini took too long ($name)', cause: e),
        retrySameModel: true,
      );
    } on Object catch (e) {
      throw _Attempt(
        GeminiException('Gemini could not be reached ($name)', cause: e),
        retrySameModel: true,
      );
    }

    final status = response.statusCode;
    if (status != 200) {
      final failure = GeminiException('Gemini answered $status ($name)');
      // Temporary: worth asking the same model again.
      if (status == 408 || status == 429 || status >= 500) {
        throw _Attempt(failure, retrySameModel: true);
      }
      // The key itself is refused, so every other model would say the same.
      if (status == 401 || status == 403 || _keyRejected(response.body)) {
        throw _Attempt(failure, fatal: true);
      }
      // 404 retired model, 400 unsupported option: try the next model.
      throw _Attempt(failure);
    }

    try {
      return _parse(response.body);
    } on GeminiException catch (e) {
      // Blocked, cut off or not JSON: another model may do better.
      throw _Attempt(e);
    }
  }

  static bool _keyRejected(String body) =>
      body.contains('API_KEY_INVALID') || body.contains('API key not valid');

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
    final blocked = (json['promptFeedback'] as Map?)?['blockReason'];
    if (blocked != null) {
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
    final parts = (candidate['content'] as Map?)?['parts'];
    if (parts is! List) {
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

/// One failed ask, and what to do about it.
class _Attempt implements Exception {
  const _Attempt(
    this.failure, {
    this.retrySameModel = false,
    this.fatal = false,
  });

  final GeminiException failure;

  /// Temporary trouble: the same model may answer a moment later.
  final bool retrySameModel;

  /// No model can help, such as a rejected key.
  final bool fatal;
}
