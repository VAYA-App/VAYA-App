import '../domain/domain.dart';
import 'candidate_builder.dart';
import 'place_selection.dart';
import 'route_orderer.dart';
import 'slot_template.dart';

/// Fills every slot without Gemini (pipeline ⑦ fallback): score each Place
/// by matching Preference Tags (plus the Taste Profile, #49) × rating and
/// take the best unused one.
class FallbackScorer {
  const FallbackScorer();

  /// Rating assumed for Places without one.
  static const defaultRating = 3.5;

  PlaceSelection select({
    required TripRequest request,
    required List<DayTemplate> days,
    required Candidates candidates,
    Map<PreferenceTag, int> tasteWeights = const {},
  }) {
    double score(Place p) =>
        (CandidateBuilder.tagMatches(request, p) +
            1 +
            _tasteBonus(p, tasteWeights)) *
        (p.rating ?? defaultRating);

    List<Place> ranked(List<Place> pool) => [...pool]
      ..sort((a, b) {
        final byScore = score(b).compareTo(score(a));
        return byScore != 0 ? byScore : a.id.compareTo(b.id);
      });

    final attractions = ranked(candidates.attractions);
    final restaurants = ranked(candidates.restaurants);
    final used = <String>{};

    SlotPick? fill(Slot slot) {
      final pool = slot.isMeal ? restaurants : attractions;
      if (pool.isEmpty) return null;
      // Repeat a place only when every candidate is already used.
      final place = pool.firstWhere(
        (p) => !used.contains(p.id),
        orElse: () => pool.first,
      );
      used.add(place.id);
      final matched = place.tags.where(request.preferenceTags.contains);
      return SlotPick(
        slot: slot,
        placeId: place.id,
        note: matched.isEmpty
            ? null
            : 'ตรงกับสไตล์: ${matched.map((t) => t.label).join(', ')}',
      );
    }

    return PlaceSelection(
      accommodationTier: CandidateBuilder.priceCap(request),
      days: [
        for (final day in days) [for (final slot in day.slots) ?fill(slot)],
      ],
    );
  }

  /// Half a point per liked tag weight, from −1 to +2, so taste nudges but
  /// never outweighs the tags chosen for this trip.
  static double _tasteBonus(Place place, Map<PreferenceTag, int> weights) {
    final sum = place.tags.fold(0, (s, t) => s + (weights[t] ?? 0));
    return (sum * 0.5).clamp(-1.0, 2.0);
  }
}
