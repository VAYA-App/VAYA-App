/// The only door to Gemini (Firebase AI Logic). Implemented in #26 and used
/// by province ranking (#25) and place selection (#27).
///
/// Gemini only *selects*; code computes money and time (ADR-0001).
abstract interface class GeminiService {
  /// Asks Gemini for JSON that matches [responseSchema].
  ///
  /// [responseSchema] is an OpenAPI-style map (`type`, `properties`,
  /// `items`, `enum`, ...) that the implementation converts to the SDK's
  /// schema type. Throws [GeminiException] on timeout, network failure or
  /// unparsable output.
  Future<Map<String, Object?>> generateJson({
    required String systemInstruction,
    required String prompt,
    required Map<String, Object?> responseSchema,
  });
}

final class GeminiException implements Exception {
  const GeminiException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'GeminiException: $message';
}
