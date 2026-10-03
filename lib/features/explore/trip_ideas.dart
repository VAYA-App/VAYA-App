import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../domain/domain.dart';
import '../trip_request/trip_request_form_notifier.dart';

const tripIdeasAsset = 'assets/mock/trip_ideas.json';

/// Which illustration heads a trip idea card.
enum TripIdeaArt { sea, sunset, temple, city }

/// A ready-made starting point shown on Explore and Home (#84). Tapping one
/// opens the Trip Request form with its province and tags picked.
final class TripIdea {
  const TripIdea({
    required this.id,
    required this.provinceId,
    required this.title,
    required this.summary,
    required this.art,
    required this.days,
    required this.budgetPerPerson,
    required this.tags,
    required this.placeIds,
  });

  factory TripIdea.fromJson(Map<String, Object?> json) => TripIdea(
    id: json['id'] as String,
    provinceId: json['provinceId'] as String,
    title: json['title'] as String,
    summary: json['summary'] as String,
    art: TripIdeaArt.values.byName(json['art'] as String),
    days: (json['days'] as num).toInt(),
    budgetPerPerson: (json['budgetPerPerson'] as num).toInt(),
    tags: [
      for (final t in json['tags'] as List) PreferenceTag.values.byName(t),
    ],
    placeIds: [for (final p in json['placeIds'] as List) p as String],
  );

  final String id;
  final String provinceId;
  final String title;
  final String summary;
  final TripIdeaArt art;
  final int days;

  /// Rough baht per person for the whole trip; shown as an estimate only.
  final int budgetPerPerson;
  final List<PreferenceTag> tags;

  /// Highlights of the idea; every id exists in the place catalog.
  final List<String> placeIds;
}

/// Hand-written ideas for now (`assets/mock/`).
final tripIdeasProvider = FutureProvider<List<TripIdea>>((ref) async {
  final json =
      jsonDecode(await rootBundle.loadString(tripIdeasAsset))
          as Map<String, Object?>;
  return [
    for (final idea in json['ideas'] as List)
      TripIdea.fromJson(idea as Map<String, Object?>),
  ];
});

/// Opens the Trip Request form pre-filled from [idea].
void openTripIdea(BuildContext context, WidgetRef ref, TripIdea idea) {
  ref
      .read(tripRequestFormProvider.notifier)
      .startWith(destinationId: idea.provinceId, tags: idea.tags);
  context.push(AppRoutes.newTrip);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'เริ่มจาก "${idea.title}" เลือกจังหวัดและสไตล์ไว้ให้แล้ว',
        ),
      ),
    );
}
