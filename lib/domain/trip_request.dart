import 'date_only.dart';
import 'enums.dart';

/// What the user asks for (CONTEXT.md: Trip Request). The Destination is
/// optional; without it the app shows Destination Suggestions first.
final class TripRequest {
  const TripRequest({
    required this.startDate,
    required this.endDate,
    required this.travellerCount,
    required this.budget,
    required this.originId,
    required this.localTransportMode,
    required this.preferenceTags,
    required this.pace,
    this.destinationId,
    this.intercityMode,
    this.note = '',
  });

  factory TripRequest.fromJson(Map<String, Object?> json) => TripRequest(
    startDate: dateFromJson(json['startDate'] as String),
    endDate: dateFromJson(json['endDate'] as String),
    travellerCount: (json['travellerCount'] as num).toInt(),
    budget: (json['budget'] as num).toInt(),
    originId: json['originId'] as String,
    destinationId: json['destinationId'] as String?,
    intercityMode: switch (json['intercityMode']) {
      final String m => IntercityMode.values.byName(m),
      _ => null,
    },
    localTransportMode: LocalTransportMode.values.byName(
      json['localTransportMode'] as String,
    ),
    preferenceTags: {
      for (final t in json['preferenceTags'] as List)
        PreferenceTag.values.byName(t),
    },
    pace: Pace.values.byName(json['pace'] as String),
    note: json['note'] as String? ?? '',
  );

  final DateTime startDate;
  final DateTime endDate;
  final int travellerCount;

  /// Total Budget in baht for all travellers.
  final int budget;
  final String originId;

  /// `null` when the user lets the system suggest one.
  final String? destinationId;

  /// Ignored when the trip stays in the Origin province.
  final IntercityMode? intercityMode;
  final LocalTransportMode localTransportMode;
  final Set<PreferenceTag> preferenceTags;
  final Pace pace;

  /// Free-text Note, passed to Gemini as-is.
  final String note;

  int get dayCount => endDate.difference(startDate).inDays + 1;
  int get nightCount => dayCount - 1;

  /// Whether [destinationId] is the Origin; such trips have no Intercity
  /// Transport.
  bool staysInOrigin(String destinationId) => destinationId == originId;

  TripRequest copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? travellerCount,
    int? budget,
    String? originId,
    String? Function()? destinationId,
    IntercityMode? Function()? intercityMode,
    LocalTransportMode? localTransportMode,
    Set<PreferenceTag>? preferenceTags,
    Pace? pace,
    String? note,
  }) => TripRequest(
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    travellerCount: travellerCount ?? this.travellerCount,
    budget: budget ?? this.budget,
    originId: originId ?? this.originId,
    destinationId: destinationId != null ? destinationId() : this.destinationId,
    intercityMode: intercityMode != null ? intercityMode() : this.intercityMode,
    localTransportMode: localTransportMode ?? this.localTransportMode,
    preferenceTags: preferenceTags ?? this.preferenceTags,
    pace: pace ?? this.pace,
    note: note ?? this.note,
  );

  Map<String, Object?> toJson() => {
    'startDate': dateToJson(startDate),
    'endDate': dateToJson(endDate),
    'travellerCount': travellerCount,
    'budget': budget,
    'originId': originId,
    if (destinationId != null) 'destinationId': destinationId,
    if (intercityMode != null) 'intercityMode': intercityMode!.name,
    'localTransportMode': localTransportMode.name,
    'preferenceTags': [for (final t in preferenceTags) t.name],
    'pace': pace.name,
    if (note.isNotEmpty) 'note': note,
  };
}
