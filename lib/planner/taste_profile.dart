import '../domain/domain.dart';

/// 👍 or 👎 on a Place (CONTEXT.md: Place Feedback).
enum PlaceFeedback { like, dislike }

/// What the traveller liked so far (CONTEXT.md: Taste Profile, #49): a
/// weight per Preference Tag from their Place Feedback, and the Places they
/// do not want to see again.
final class TasteProfile {
  const TasteProfile([this.feedback = const {}]);

  /// Place id → the traveller's feedback.
  final Map<String, PlaceFeedback> feedback;

  bool get isEmpty => feedback.isEmpty;

  Set<String> get disliked => {
    for (final MapEntry(:key, :value) in feedback.entries)
      if (value == PlaceFeedback.dislike) key,
  };

  /// +1 for every liked Place with the tag, −1 for every disliked one.
  Map<PreferenceTag, int> tagWeights(PlaceCatalog catalog) {
    final weights = <PreferenceTag, int>{};
    for (final MapEntry(key: id, value: f) in feedback.entries) {
      final place = catalog.findPlace(id);
      if (place == null) continue;
      for (final tag in place.tags) {
        weights[tag] = (weights[tag] ?? 0) + (f == PlaceFeedback.like ? 1 : -1);
      }
    }
    return weights..removeWhere((_, w) => w == 0);
  }

  TasteProfile withFeedback(String placeId, PlaceFeedback? value) =>
      TasteProfile({
        for (final e in feedback.entries)
          if (e.key != placeId) e.key: e.value,
        placeId: ?value,
      });
}
