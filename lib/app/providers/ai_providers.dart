import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../ai/gemini_service.dart';
import '../../ai/mock_gemini_service.dart';
import '../../ai/rest_gemini_service.dart';

/// `flutter run --dart-define-from-file=env.json` (#144). Never commit it.
const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
const _model = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: RestGeminiService.defaultModel,
);

/// Comma separated, tried in order when [_model] fails. Empty uses the
/// built-in list.
const _fallbackModels = String.fromEnvironment('GEMINI_FALLBACK_MODELS');

/// Real Gemini when the app was built with an API key; otherwise the mock,
/// which fails every call so callers use their fallbacks and the app still
/// works offline. Firebase AI Logic is deferred (#26).
final geminiServiceProvider = Provider<GeminiService>((ref) {
  if (_apiKey.isEmpty) return const MockGeminiService();
  final client = http.Client();
  ref.onDispose(client.close);
  return RestGeminiService(
    client,
    apiKey: _apiKey,
    model: _model,
    fallbackModels: _fallbackModels.isEmpty
        ? RestGeminiService.defaultFallbackModels
        : _fallbackModels.split(','),
  );
});
