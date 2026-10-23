import '../../domain/domain.dart';
import '../../planner/candidate_builder.dart';
import '../../planner/place_selection.dart';
import '../../planner/route_orderer.dart';
import '../../planner/slot_template.dart';

/// Pipeline step ⑥: Gemini picks a Place for every slot. It only chooses;
/// order, times and money are computed by code (ADR-0001). The Free-text
/// Note goes straight into this prompt instead of a separate call.
abstract final class SelectPlacesPrompt {
  static const systemInstruction = '''
You are a Thai travel planner. Fill every slot of every day with one Place
from the candidate list.

Rules:
- Use only placeId values from the candidates. Never invent places.
- Slots "lunch" and "dinner" take a restaurant. Every other slot takes an
  attraction.
- Never use the same placeId twice in the whole trip.
- Prefer places matching the traveller's tags and note; respect constraints
  in the note (e.g. elderly, vegetarian, no long walks).
- Keep each day's places reasonably close to each other.
- "note" is one short Thai sentence (max 60 characters) on why it fits.
- accommodationTier is 1–4 (price level) and must suit the budget.
- Do not compute prices or times.''';

  /// OpenAPI-style schema for `GeminiService.generateJson`.
  static final Map<String, Object?> responseSchema = {
    'type': 'object',
    'properties': {
      'days': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'slots': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'slot': {
                    'type': 'string',
                    'enum': [for (final s in Slot.values) s.name],
                  },
                  'placeId': {'type': 'string'},
                  'note': {'type': 'string'},
                },
                'required': ['slot', 'placeId', 'note'],
              },
            },
          },
          'required': ['slots'],
        },
      },
      'accommodationTier': {'type': 'integer', 'minimum': 1, 'maximum': 4},
    },
    'required': ['days', 'accommodationTier'],
  };

  /// The user prompt. [previousErrors] come from the validator when this is
  /// the retry (#28).
  static String build({
    required TripRequest request,
    required Province province,
    required List<DayTemplate> days,
    required Candidates candidates,
    Map<PreferenceTag, int> tasteWeights = const {},
    List<String> previousErrors = const [],
  }) {
    String tags(bool liked) => [
      for (final MapEntry(key: tag, value: w) in tasteWeights.entries)
        if (liked ? w > 0 : w < 0) tag.name,
    ].join(', ');
    String line(Place p) => [
      p.id,
      p.category.name,
      p.name,
      'tags=${p.tags.map((t) => t.name).join(',')}',
      'price=${p.priceLevel}',
      if (p.rating != null) 'rating=${p.rating}',
      p.shortDescription,
    ].join(' | ');

    return [
      'Destination: ${province.name} (${province.id})',
      'Dates: ${dateToJson(request.startDate)} to ${dateToJson(request.endDate)}',
      'Travellers: ${request.travellerCount}',
      'Total budget (THB, all travellers): ${request.budget}',
      'Highest affordable price level: ${CandidateBuilder.priceCap(request)}',
      'Pace: ${request.pace.name}',
      'Tags: ${request.preferenceTags.map((t) => t.name).join(', ')}',
      if (request.note.isNotEmpty) 'Traveller note: ${request.note}',
      // From thumbs up/down on earlier trips (#49).
      if (tags(true).isNotEmpty) 'Liked before: ${tags(true)}',
      if (tags(false).isNotEmpty) 'Disliked before: ${tags(false)}',
      '',
      'Slots to fill:',
      for (final (i, d) in days.indexed)
        'Day ${i + 1} (${dateToJson(d.date)}): '
            '${d.slots.map((s) => s.name).join(', ')}',
      '',
      'Candidates (placeId | category | name | tags | price | rating | about):',
      for (final p in [...candidates.attractions, ...candidates.restaurants])
        line(p),
      if (previousErrors.isNotEmpty) ...[
        '',
        'Your previous answer was rejected. Fix these problems:',
        for (final e in previousErrors) '- $e',
      ],
    ].join('\n');
  }

  /// Reads Gemini's JSON. Throws [FormatException] when the shape is wrong;
  /// content problems (unknown ids, wrong slots) are the validator's job.
  static PlaceSelection parse(Map<String, Object?> json) {
    try {
      final days = json['days']! as List;
      return PlaceSelection(
        accommodationTier: (json['accommodationTier']! as num).toInt(),
        days: [
          for (final day in days)
            [
              for (final s in (day as Map)['slots'] as List)
                SlotPick(
                  slot: Slot.values.byName((s as Map)['slot'] as String),
                  placeId: s['placeId'] as String,
                  note: switch (s['note']) {
                    final String n when n.trim().isNotEmpty => n.trim(),
                    _ => null,
                  },
                ),
            ],
        ],
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Unexpected place selection JSON: $e');
    }
  }
}
