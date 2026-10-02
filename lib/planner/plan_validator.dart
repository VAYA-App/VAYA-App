import '../domain/domain.dart';
import 'candidate_builder.dart';
import 'place_selection.dart';
import 'slot_template.dart';

/// Checks a [PlaceSelection] before it is trusted (pipeline ⑦). Messages are
/// in English because they are sent back to Gemini on the retry.
class PlanValidator {
  const PlanValidator();

  /// Empty when the selection is usable.
  List<String> validate(
    PlaceSelection selection,
    List<DayTemplate> days,
    Candidates candidates,
  ) {
    final errors = <String>[];
    final tier = selection.accommodationTier;
    if (tier < 1 || tier > 4) {
      errors.add('accommodationTier must be 1-4, got $tier');
    }
    if (selection.days.length != days.length) {
      errors.add('Expected ${days.length} days, got ${selection.days.length}');
    }

    final seen = <String>{};
    for (var i = 0; i < selection.days.length && i < days.length; i++) {
      final picks = selection.days[i];
      final expected = days[i].slots;
      final got = [for (final p in picks) p.slot];
      if (!_sameSlots(got, expected)) {
        errors.add(
          'Day ${i + 1}: expected slots ${expected.map((s) => s.name).toList()}, '
          'got ${got.map((s) => s.name).toList()}',
        );
      }
      for (final pick in picks) {
        final label = 'Day ${i + 1} ${pick.slot.name}';
        final place = candidates.find(pick.placeId);
        if (place == null) {
          errors.add('$label: unknown placeId "${pick.placeId}"');
          continue;
        }
        final needed = pick.slot.isMeal
            ? PlaceCategory.restaurant
            : PlaceCategory.attraction;
        if (place.category != needed) {
          errors.add(
            '$label: "${pick.placeId}" is a ${place.category.name}, '
            'expected a ${needed.name}',
          );
        }
        if (!seen.add(pick.placeId)) {
          errors.add('$label: "${pick.placeId}" is used more than once');
        }
      }
    }
    return errors;
  }

  static bool _sameSlots(List<Slot> a, List<Slot> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
