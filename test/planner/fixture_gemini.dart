import 'package:vaya_app/ai/gemini_service.dart';

import 'test_data.dart';

/// A [GeminiService] that answers every call with the same recorded JSON, so
/// a test gets the same plan on every run (#32).
///
/// Without a [fixture] it fails like the offline mock, which sends the
/// pipeline to its fallback.
class FixtureGemini implements GeminiService {
  FixtureGemini([this.fixture]);

  /// Path of the response JSON, relative to the package root.
  final String? fixture;

  /// Every prompt received. More than one means the answer failed validation
  /// and the selector retried.
  final prompts = <String>[];

  @override
  Future<Map<String, Object?>> generateJson({
    required String systemInstruction,
    required String prompt,
    required Map<String, Object?> responseSchema,
  }) async {
    prompts.add(prompt);
    final path = fixture;
    if (path == null) {
      throw const GeminiException('ไม่มี fixture (จำลองตอนออฟไลน์)');
    }
    return readJson(path);
  }
}
