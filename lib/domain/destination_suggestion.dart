import 'enums.dart';

/// A province the system proposes when the user gives no Destination (M3).
final class DestinationSuggestion {
  const DestinationSuggestion({
    required this.provinceId,
    required this.reason,
    required this.highlightTags,
    required this.minimumCost,
  });

  factory DestinationSuggestion.fromJson(Map<String, Object?> json) =>
      DestinationSuggestion(
        provinceId: json['provinceId'] as String,
        reason: json['reason'] as String,
        highlightTags: [
          for (final t in json['highlightTags'] as List)
            PreferenceTag.values.byName(t),
        ],
        minimumCost: (json['minimumCost'] as num).toInt(),
      );

  final String provinceId;

  /// Thai explanation from Gemini (or a template when Gemini fails).
  final String reason;
  final List<PreferenceTag> highlightTags;

  /// Cheapest possible total for this request, computed by code.
  final int minimumCost;

  Map<String, Object?> toJson() => {
    'provinceId': provinceId,
    'reason': reason,
    'highlightTags': [for (final t in highlightTags) t.name],
    'minimumCost': minimumCost,
  };
}
