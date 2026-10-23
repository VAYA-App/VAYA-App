import '../../domain/domain.dart';
import '../../planner/plan_editor.dart';

/// The AI chat (#46): Gemini reads the plan and the traveller's message,
/// answers in Thai and proposes `replaceStop` / `removeStop` edits that
/// code checks and the traveller confirms (ADR-0001).
abstract final class EditPlanPrompt {
  static const systemInstruction = '''
You are a Thai travel planner helping a traveller adjust their trip plan.

Rules:
- "reply" is short, friendly Thai (max 200 characters). If you propose
  edits, describe them and ask the traveller to confirm. If the request is
  unclear or impossible, ask a question and propose no edits.
- Edits use 1-based "day" and "stop" numbers from the plan.
- "replaceStop" needs "placeId" from the candidate list only. Never invent
  places. Lunch and dinner stops take a restaurant; every other stop an
  attraction.
- "removeStop" removes the stop; do not remove every stop of a day.
- Do not compute prices or times; the app does.''';

  /// OpenAPI-style schema for `GeminiService.generateJson`.
  static final Map<String, Object?> responseSchema = {
    'type': 'object',
    'properties': {
      'reply': {'type': 'string'},
      'edits': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['replaceStop', 'removeStop'],
            },
            'day': {'type': 'integer', 'minimum': 1},
            'stop': {'type': 'integer', 'minimum': 1},
            'placeId': {'type': 'string'},
          },
          'required': ['action', 'day', 'stop'],
        },
      },
    },
    'required': ['reply', 'edits'],
  };

  static String build({
    required String message,
    required TripPlan plan,
    required TripRequest request,
    required PlaceCatalog catalog,
    List<String> previousErrors = const [],
  }) {
    String describe(Place p) => [
      p.id,
      p.category.name,
      p.name,
      ?p.area,
      'tags=${p.tags.map((t) => t.name).join(',')}',
      'price=${p.priceLevel}',
      if (p.rating case final rating?) 'rating=$rating',
    ].join(' | ');

    final used = {
      for (final day in plan.days)
        for (final stop in day.stops) stop.placeId,
    };
    return [
      'Travellers: ${request.travellerCount}, budget ${request.budget} THB, '
          'pace ${request.pace.name}, tags '
          '${request.preferenceTags.map((t) => t.name).join(', ')}',
      if (request.note.isNotEmpty) 'Traveller note: ${request.note}',
      '',
      'Current plan (stop number | slot | time | place):',
      for (final (d, day) in plan.days.indexed) ...[
        'Day ${d + 1} (${dateToJson(day.date)}):',
        for (final (s, stop) in day.stops.indexed)
          '  ${s + 1} | ${stop.slot.name} | ${stop.start} | '
              '${describe(catalog.place(stop.placeId))}',
      ],
      '',
      'Candidates not in the plan (placeId | category | name | area | tags | price | rating):',
      for (final place in catalog.placesIn(plan.destinationId))
        if (place.category != PlaceCategory.accommodation &&
            !used.contains(place.id))
          describe(place),
      '',
      'Traveller message: $message',
      if (previousErrors.isNotEmpty) ...[
        '',
        'Your previous answer was rejected. Fix these problems:',
        for (final e in previousErrors) '- $e',
      ],
    ].join('\n');
  }

  /// Reads Gemini's JSON into a reply and edits with 0-based indices.
  /// Throws [FormatException] when the shape is wrong; whether the edits
  /// fit the plan is checked by `PlanEditor`.
  static ({String reply, List<PlanEdit> edits}) parse(
    Map<String, Object?> json,
  ) {
    try {
      return (
        reply: (json['reply']! as String).trim(),
        edits: [
          for (final e in json['edits']! as List)
            switch ((e as Map)['action']) {
              'removeStop' => RemoveStop(
                day: (e['day'] as num).toInt() - 1,
                index: (e['stop'] as num).toInt() - 1,
              ),
              'replaceStop' => ReplaceStop(
                day: (e['day'] as num).toInt() - 1,
                index: (e['stop'] as num).toInt() - 1,
                placeId: e['placeId'] as String,
              ),
              final action => throw FormatException('Unknown action $action'),
            },
        ],
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Unexpected edit plan JSON: $e');
    }
  }
}
