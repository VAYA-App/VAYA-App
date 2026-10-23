import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gemini_service.dart';

/// Gemini through the Gemini Developer API with an API key, until Firebase
/// AI Logic is set up (#26, #144). The key ships inside the app, so use a
/// key restricted to this API and never commit it.
class RestGeminiService implements GeminiService {
  RestGeminiService(
    this._client, {
    required this.apiKey,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 30),
    Uri? server,
  }) : _server =
           server ?? Uri.parse('https://generativelanguage.googleapis.com');

  static const defaultModel = 'gemini-flash-latest';

  final http.Client _client;
  final String apiKey;
  final String model;
  final Duration timeout;
  final Uri _server;

  @override
  Future<Map<String, Object?>> generateJson({
    required String systemInstruction,
    required String prompt,
    required Map<String, Object?> responseSchema,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _server.replace(path: '/v1beta/models/$model:generateContent'),
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
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
            }),
          )
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw GeminiException('Gemini took too long', cause: e);
    } on Exception catch (e) {
      throw GeminiException('Gemini could not be reached', cause: e);
    }

    if (response.statusCode != 200) {
      throw GeminiException('Gemini answered ${response.statusCode}');
    }
    try {
      final json = jsonDecode(response.body) as Map<String, Object?>;
      final candidate = (json['candidates']! as List).first as Map;
      final parts = (candidate['content']! as Map)['parts']! as List;
      final text = [for (final p in parts) (p as Map)['text'] ?? ''].join();
      return jsonDecode(text) as Map<String, Object?>;
    } on Object catch (e) {
      throw GeminiException('Gemini returned no usable JSON', cause: e);
    }
  }
}
