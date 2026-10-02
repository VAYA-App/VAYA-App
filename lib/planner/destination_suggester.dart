import '../domain/domain.dart';

/// Pipeline steps ② (filter, #24) and ③ (rank with Gemini, #25).
abstract interface class DestinationSuggester {
  /// Provinces that fit [request], best first. Empty when none fits the
  /// budget or season.
  Future<List<DestinationSuggestion>> suggest(TripRequest request);
}
