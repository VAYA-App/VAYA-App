import 'trip_plan.dart';
import 'trip_request.dart';

/// A Trip Plan saved by a user, stored at Firestore `trips/{id}` (M8).
final class Trip {
  const Trip({
    required this.ownerUid,
    required this.createdAt,
    required this.updatedAt,
    required this.request,
    required this.plan,
    this.id,
  });

  /// [id] comes from the Firestore document id, not from the JSON body.
  factory Trip.fromJson(String id, Map<String, Object?> json) => Trip(
    id: id,
    ownerUid: json['ownerUid'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    request: TripRequest.fromJson(json['request'] as Map<String, Object?>),
    plan: TripPlan.fromJson(json['plan'] as Map<String, Object?>),
  );

  /// `null` until the trip is saved.
  final String? id;
  final String ownerUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TripRequest request;
  final TripPlan plan;

  bool get isSaved => id != null;

  Trip copyWith({String? id, DateTime? updatedAt, TripPlan? plan}) => Trip(
    id: id ?? this.id,
    ownerUid: ownerUid,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    request: request,
    plan: plan ?? this.plan,
  );

  /// Timestamps are ISO-8601 strings here; the Firestore repository (#41)
  /// may convert them to `Timestamp`.
  Map<String, Object?> toJson() => {
    'ownerUid': ownerUid,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'request': request.toJson(),
    'plan': plan.toJson(),
  };
}
