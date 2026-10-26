import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/data_providers.dart';
import '../../data/photo_catalog.dart';
import '../../domain/domain.dart';
import '../../planner/taste_profile.dart';

/// Attractions to suggest on the home page (#172): those whose Preference
/// Tags the Taste Profile likes most, never one the traveller disliked.
/// With no feedback yet, the best rated. Places with a photo of their own
/// come first so the row looks like the real place.
List<Place> pickPlaces(
  PlaceCatalog catalog,
  TasteProfile taste,
  PhotoCatalog photos, {
  int limit = 8,
}) {
  final weights = taste.tagWeights(catalog);
  final disliked = taste.disliked;
  double score(Place p) =>
      p.tags.fold<double>(0, (s, t) => s + (weights[t] ?? 0)) +
      (p.rating ?? 0) / 10;

  final candidates =
      [
        for (final p in catalog.places)
          if (p.category == PlaceCategory.attraction &&
              !disliked.contains(p.id))
            p,
      ]..sort((a, b) {
        final photo =
            (photos.hasOwnPhoto(b.id) ? 1 : 0) -
            (photos.hasOwnPhoto(a.id) ? 1 : 0);
        return photo != 0 ? photo : score(b).compareTo(score(a));
      });
  return candidates.take(limit).toList();
}

final placePicksProvider = FutureProvider<List<Place>>((ref) async {
  final taste = ref.watch(tasteProfileProvider);
  final catalog = await ref.watch(placeCatalogProvider.future);
  final photos = await ref.watch(photoCatalogProvider.future);
  return pickPlaces(catalog, taste, photos);
});
