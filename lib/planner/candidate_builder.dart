import '../domain/domain.dart';

/// The Places of one province the planner may choose from (pipeline ⑤).
final class Candidates {
  Candidates({
    required this.attractions,
    required this.restaurants,
    required this.accommodations,
  }) : _byId = {
         for (final p in [...attractions, ...restaurants, ...accommodations])
           p.id: p,
       };

  final List<Place> attractions;
  final List<Place> restaurants;
  final List<Place> accommodations;
  final Map<String, Place> _byId;

  Iterable<Place> get all => _byId.values;

  Place? find(String placeId) => _byId[placeId];
}

/// Keeps the candidate list small and affordable so Gemini answers fast and
/// cannot pick something the budget rules out.
class CandidateBuilder {
  const CandidateBuilder();

  /// About 80 Places in total, as PROJECT-PLAN §11 suggests.
  static const maxAttractions = 40;
  static const maxRestaurants = 30;
  static const maxAccommodations = 10;

  Candidates build({
    required TripRequest request,
    required String provinceId,
    required PlaceCatalog catalog,
    Set<String> excludedPlaceIds = const {},
  }) {
    final cap = priceCap(request);
    List<Place> pick(PlaceCategory category, int limit) {
      final all = catalog
          .placesIn(provinceId, category: category)
          .where((p) => !excludedPlaceIds.contains(p.id))
          .toList();
      var affordable = all.where((p) => p.priceLevel <= cap).toList();
      // Never leave a category empty: fall back to the cheapest level.
      if (affordable.isEmpty && all.isNotEmpty) {
        final cheapest = all
            .map((p) => p.priceLevel)
            .reduce((a, b) => a < b ? a : b);
        affordable = all.where((p) => p.priceLevel == cheapest).toList();
      }
      affordable.sort((a, b) => _compare(request, a, b));
      return affordable.take(limit).toList();
    }

    return Candidates(
      attractions: pick(PlaceCategory.attraction, maxAttractions),
      restaurants: pick(PlaceCategory.restaurant, maxRestaurants),
      accommodations: pick(PlaceCategory.accommodation, maxAccommodations),
    );
  }

  /// Highest Price Level the budget allows, from the spend per person per
  /// day.
  static int priceCap(TripRequest request) {
    final perPersonPerDay =
        request.budget / request.travellerCount / request.dayCount;
    if (perPersonPerDay < 700) return 1;
    if (perPersonPerDay < 1500) return 2;
    if (perPersonPerDay < 3000) return 3;
    return 4;
  }

  /// How many of the user's Preference Tags [place] has.
  static int tagMatches(TripRequest request, Place place) =>
      place.tags.where(request.preferenceTags.contains).length;

  /// Better matches first, then higher rating, then id for stable output.
  static int _compare(TripRequest request, Place a, Place b) {
    final byTags = tagMatches(request, b).compareTo(tagMatches(request, a));
    if (byTags != 0) return byTags;
    final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
    if (byRating != 0) return byRating;
    return a.id.compareTo(b.id);
  }
}
