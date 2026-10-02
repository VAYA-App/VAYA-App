import 'gemini_service.dart';

/// Builds a canned response for a request, or returns `null` to fail it.
typedef MockGeminiResponder =
    Map<String, Object?>? Function(String systemInstruction, String prompt);

/// Stand-in for Gemini until Firebase AI Logic is set up (deferred, see #26).
///
/// By default every call fails with [GeminiException], so callers exercise
/// their fallbacks (fallback scorer #28, cost-ordered ranking #25) and the
/// whole app still works offline. Tests can pass a [responder] that returns
/// fixture JSON instead.
class MockGeminiService implements GeminiService {
  const MockGeminiService({this.responder});

  final MockGeminiResponder? responder;

  @override
  Future<Map<String, Object?>> generateJson({
    required String systemInstruction,
    required String prompt,
    required Map<String, Object?> responseSchema,
  }) async {
    final response = responder?.call(systemInstruction, prompt);
    if (response == null) {
      throw const GeminiException('ยังไม่ได้เชื่อมต่อ Gemini (โหมด mock)');
    }
    return response;
  }
}
