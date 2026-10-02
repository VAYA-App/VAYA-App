import 'route_orderer.dart';

/// Which Place goes in each slot of each day, plus the accommodation price
/// tier. Comes from Gemini (#27) or the fallback scorer (#28).
final class PlaceSelection {
  const PlaceSelection({required this.days, required this.accommodationTier});

  /// One list per day, in the order of that day's template slots.
  final List<List<SlotPick>> days;

  /// Price Level 1–4 for the Night Stay.
  final int accommodationTier;
}
