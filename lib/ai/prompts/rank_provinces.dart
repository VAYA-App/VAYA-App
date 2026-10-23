import '../../domain/domain.dart';
import '../../planner/province_filter.dart';

/// One province as Gemini ranked it.
typedef RankedProvince = ({
  String provinceId,
  String reason,
  List<PreferenceTag> highlightTags,
});

/// Pipeline step ③: Gemini orders the provinces that passed the filter (#24)
/// and says why each suits the traveller. Code already decided which
/// provinces fit and what they cost at least (ADR-0001).
abstract final class RankProvincesPrompt {
  static const systemInstruction = '''
You are a Thai travel advisor. Rank the candidate provinces from best to
worst fit for this traveller.

Rules:
- Use only provinceId values from the candidates. Never invent provinces.
- List every candidate exactly once.
- "reason" is one or two short Thai sentences (max 120 characters) on why
  the province suits this traveller: their tags, note and travel month.
- "highlightTags" are 1–3 tags from the province's own tags that best match
  the traveller.
- Do not compute or mention prices.''';

  /// OpenAPI-style schema for `GeminiService.generateJson`.
  static final Map<String, Object?> responseSchema = {
    'type': 'object',
    'properties': {
      'provinces': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'provinceId': {'type': 'string'},
            'reason': {'type': 'string'},
            'highlightTags': {
              'type': 'array',
              'items': {
                'type': 'string',
                'enum': [for (final t in PreferenceTag.values) t.name],
              },
            },
          },
          'required': ['provinceId', 'reason', 'highlightTags'],
        },
      },
    },
    'required': ['provinces'],
  };

  /// The user prompt. [previousErrors] come from the validator when this is
  /// the retry.
  static String build({
    required TripRequest request,
    required List<ProvinceCandidate> candidates,
    List<String> previousErrors = const [],
  }) {
    final month = request.startDate.month;
    String line(ProvinceCandidate c) => [
      c.province.id,
      c.province.name,
      'tags=${c.province.tags.map((t) => t.name).join(',')}',
      'season=${c.province.seasonFor(month).name}',
      'minimumCost=${c.minimumCost}',
      c.province.seasonNote,
    ].join(' | ');

    return [
      'Dates: ${dateToJson(request.startDate)} to ${dateToJson(request.endDate)}',
      'Travellers: ${request.travellerCount}',
      'Total budget (THB, all travellers): ${request.budget}',
      'Origin: ${request.originId}',
      'Pace: ${request.pace.name}',
      'Tags: ${request.preferenceTags.map((t) => t.name).join(', ')}',
      if (request.note.isNotEmpty) 'Traveller note: ${request.note}',
      '',
      'Candidates (provinceId | name | tags | season | minimumCost | season note):',
      for (final c in candidates) line(c),
      if (previousErrors.isNotEmpty) ...[
        '',
        'Your previous answer was rejected. Fix these problems:',
        for (final e in previousErrors) '- $e',
      ],
    ].join('\n');
  }

  /// Reads Gemini's JSON. Throws [FormatException] when the shape is wrong;
  /// unknown or repeated ids are the validator's job. Unknown tags are
  /// dropped.
  static List<RankedProvince> parse(Map<String, Object?> json) {
    try {
      return [
        for (final p in json['provinces']! as List)
          (
            provinceId: (p as Map)['provinceId'] as String,
            reason: (p['reason'] as String).trim(),
            highlightTags: [
              for (final t in p['highlightTags'] as List)
                ?PreferenceTag.values.asNameMap()[t],
            ],
          ),
      ];
    } catch (e) {
      throw FormatException('Unexpected province ranking JSON: $e');
    }
  }
}
