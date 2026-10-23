import '../ai/gemini_service.dart';
import '../ai/prompts/rank_provinces.dart';
import '../domain/domain.dart';
import 'cost_calculator.dart';
import 'destination_suggester.dart';
import 'province_filter.dart';

/// Pipeline ②–③: filter provinces by code (#24), let Gemini rank them with
/// a reason, retry once with the problems listed, then fall back to
/// [fallbackOrder] with a template reason (#25).
class GeminiDestinationSuggester implements DestinationSuggester {
  const GeminiDestinationSuggester({
    required this.gemini,
    required this.loadCatalog,
    required this.loadCostCalculator,
  });

  final GeminiService gemini;
  final Future<PlaceCatalog> Function() loadCatalog;
  final Future<CostCalculator> Function() loadCostCalculator;

  static const maxAttempts = 2;

  @override
  Future<List<DestinationSuggestion>> suggest(TripRequest request) async {
    final catalog = await loadCatalog();
    final candidates = ProvinceFilter(
      await loadCostCalculator(),
    ).filter(request: request, catalog: catalog);
    if (candidates.isEmpty) return const [];

    var errors = <String>[];
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final json = await gemini.generateJson(
          systemInstruction: RankProvincesPrompt.systemInstruction,
          prompt: RankProvincesPrompt.build(
            request: request,
            candidates: candidates,
            previousErrors: errors,
          ),
          responseSchema: RankProvincesPrompt.responseSchema,
        );
        final ranked = RankProvincesPrompt.parse(json);
        errors = validate(ranked, candidates);
        if (errors.isEmpty) {
          return _merge(ranked, candidates, request);
        }
      } on GeminiException {
        // Offline, timed out or not connected: asking again will not help.
        break;
      } on FormatException catch (e) {
        errors = ['The answer did not match the JSON schema: ${e.message}'];
      }
    }
    return [
      for (final c in fallbackOrder(candidates, request))
        _fromTemplate(c, request),
    ];
  }

  /// Without Gemini: most of the traveller's tags first, then the better
  /// season, then the cheaper trip. Cost alone would always put the origin
  /// province first, since it has no intercity fare.
  static List<ProvinceCandidate> fallbackOrder(
    List<ProvinceCandidate> candidates,
    TripRequest request,
  ) {
    final month = request.startDate.month;
    int matches(Province p) =>
        p.tags.where(request.preferenceTags.contains).length;
    return [...candidates]..sort(
      (a, b) => switch (matches(b.province).compareTo(matches(a.province))) {
        0 => switch (a.province
            .seasonFor(month)
            .index
            .compareTo(b.province.seasonFor(month).index)) {
          0 => a.minimumCost.compareTo(b.minimumCost),
          final bySeason => bySeason,
        },
        final byTags => byTags,
      },
    );
  }

  /// Problems with Gemini's ranking, in English for the retry prompt.
  static List<String> validate(
    List<RankedProvince> ranked,
    List<ProvinceCandidate> candidates,
  ) {
    final allowed = {for (final c in candidates) c.province.id};
    final seen = <String>{};
    return [
      if (ranked.isEmpty) 'The list of provinces is empty.',
      for (final r in ranked) ...[
        if (!allowed.contains(r.provinceId))
          '"${r.provinceId}" is not one of the candidates.',
        if (!seen.add(r.provinceId)) '"${r.provinceId}" is listed twice.',
        if (r.reason.isEmpty) '"${r.provinceId}" has no reason.',
      ],
    ];
  }

  /// Gemini's order and reasons; a candidate it left out still follows at
  /// the end, so no province that fits is hidden.
  static List<DestinationSuggestion> _merge(
    List<RankedProvince> ranked,
    List<ProvinceCandidate> candidates,
    TripRequest request,
  ) {
    final byId = {for (final c in candidates) c.province.id: c};
    final ids = {for (final r in ranked) r.provinceId};
    return [
      for (final r in ranked)
        DestinationSuggestion(
          provinceId: r.provinceId,
          reason: r.reason,
          highlightTags: r.highlightTags.isEmpty
              ? _highlights(byId[r.provinceId]!.province, request)
              : r.highlightTags,
          minimumCost: byId[r.provinceId]!.minimumCost,
        ),
      for (final c in candidates)
        if (!ids.contains(c.province.id)) _fromTemplate(c, request),
    ];
  }

  static DestinationSuggestion _fromTemplate(
    ProvinceCandidate candidate,
    TripRequest request,
  ) {
    final province = candidate.province;
    final matched = [
      for (final t in province.tags)
        if (request.preferenceTags.contains(t)) t,
    ];
    final season = province.seasonFor(request.startDate.month);
    final fit = matched.isEmpty
        ? 'เที่ยวได้ในงบของคุณ'
        : 'มี${matched.map((t) => t.label).join(' ')}ตรงกับสไตล์ของคุณ';
    final when = switch (season) {
      SeasonRating.good => 'และเดือนที่ไปเป็นช่วงที่ดี',
      SeasonRating.ok => 'และเดือนที่ไปยังเที่ยวได้',
      SeasonRating.avoid => 'แต่เดือนที่ไปไม่ค่อยเหมาะ',
    };
    return DestinationSuggestion(
      provinceId: province.id,
      reason: '$fit $when',
      highlightTags: _highlights(province, request),
      minimumCost: candidate.minimumCost,
    );
  }

  /// Up to three of the province's tags, the traveller's own first.
  static List<PreferenceTag> _highlights(
    Province province,
    TripRequest request,
  ) => [
    ...province.tags.where(request.preferenceTags.contains),
    ...province.tags.where((t) => !request.preferenceTags.contains(t)),
  ].take(3).toList();
}
