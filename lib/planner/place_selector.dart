import '../ai/gemini_service.dart';
import '../ai/prompts/select_places.dart';
import '../domain/domain.dart';
import 'candidate_builder.dart';
import 'fallback_scorer.dart';
import 'place_selection.dart';
import 'plan_validator.dart';
import 'slot_template.dart';

enum SelectionSource { gemini, fallback }

/// Pipeline ⑥–⑦: ask Gemini, validate, retry once with the problems listed,
/// then fall back to [FallbackScorer]. Always returns a usable selection.
class PlaceSelector {
  const PlaceSelector({
    required this.gemini,
    this.validator = const PlanValidator(),
    this.fallback = const FallbackScorer(),
  });

  final GeminiService gemini;
  final PlanValidator validator;
  final FallbackScorer fallback;

  static const maxAttempts = 2;

  Future<({PlaceSelection selection, SelectionSource source})> select({
    required TripRequest request,
    required Province province,
    required List<DayTemplate> days,
    required Candidates candidates,
  }) async {
    var errors = <String>[];
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final json = await gemini.generateJson(
          systemInstruction: SelectPlacesPrompt.systemInstruction,
          prompt: SelectPlacesPrompt.build(
            request: request,
            province: province,
            days: days,
            candidates: candidates,
            previousErrors: errors,
          ),
          responseSchema: SelectPlacesPrompt.responseSchema,
        );
        final selection = SelectPlacesPrompt.parse(json);
        errors = validator.validate(selection, days, candidates);
        if (errors.isEmpty) {
          return (selection: selection, source: SelectionSource.gemini);
        }
      } on GeminiException {
        // Offline, timed out or not connected: asking again will not help.
        break;
      } on FormatException catch (e) {
        errors = ['The answer did not match the JSON schema: ${e.message}'];
      }
    }
    return (
      selection: fallback.select(
        request: request,
        days: days,
        candidates: candidates,
      ),
      source: SelectionSource.fallback,
    );
  }
}
