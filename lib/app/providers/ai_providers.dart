import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/gemini_service.dart';
import '../../ai/mock_gemini_service.dart';

/// Mock for now: every call fails so callers use their fallbacks.
/// The Firebase AI Logic implementation is deferred (#26).
final geminiServiceProvider = Provider<GeminiService>(
  (ref) => const MockGeminiService(),
);
