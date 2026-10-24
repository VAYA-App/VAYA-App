import 'clock_time.dart';
import 'cost_estimate.dart';
import 'date_only.dart';
import 'enums.dart';

/// The result of one Trip Request: one Destination, a Day Plan per day,
/// Intercity Transport and a Cost Estimate (CONTEXT.md: Trip Plan).
final class TripPlan {
  const TripPlan({
    required this.destinationId,
    required this.status,
    required this.nightStays,
    required this.days,
    required this.cost,
    this.intercity,
    this.overBudgetAdvice = const [],
  });

  factory TripPlan.fromJson(Map<String, Object?> json) => TripPlan(
    destinationId: json['destinationId'] as String,
    status: PlanStatus.values.byName(json['status'] as String),
    intercity: switch (json['intercity']) {
      final Map<String, Object?> leg => IntercityLeg.fromJson(leg),
      _ => null,
    },
    nightStays: [
      for (final n in json['nightStays'] as List)
        NightStay.fromJson(n as Map<String, Object?>),
    ],
    days: [
      for (final d in json['days'] as List)
        DayPlan.fromJson(d as Map<String, Object?>),
    ],
    cost: CostEstimate.fromJson(json['cost'] as Map<String, Object?>),
    overBudgetAdvice: [
      for (final a in json['overBudgetAdvice'] as List? ?? const [])
        BudgetAdvice.fromJson(a as Map<String, Object?>),
    ],
  );

  final String destinationId;
  final PlanStatus status;

  /// `null` when the trip stays in the Origin province.
  final IntercityLeg? intercity;
  final List<NightStay> nightStays;
  final List<DayPlan> days;
  final CostEstimate cost;
  final List<BudgetAdvice> overBudgetAdvice;

  TripPlan copyWith({
    PlanStatus? status,
    IntercityLeg? Function()? intercity,
    List<NightStay>? nightStays,
    List<DayPlan>? days,
    CostEstimate? cost,
    List<BudgetAdvice>? overBudgetAdvice,
  }) => TripPlan(
    destinationId: destinationId,
    status: status ?? this.status,
    intercity: intercity != null ? intercity() : this.intercity,
    nightStays: nightStays ?? this.nightStays,
    days: days ?? this.days,
    cost: cost ?? this.cost,
    overBudgetAdvice: overBudgetAdvice ?? this.overBudgetAdvice,
  );

  Map<String, Object?> toJson() => {
    'destinationId': destinationId,
    'status': status.name,
    if (intercity != null) 'intercity': intercity!.toJson(),
    'nightStays': [for (final n in nightStays) n.toJson()],
    'days': [for (final d in days) d.toJson()],
    'cost': cost.toJson(),
    'overBudgetAdvice': [for (final a in overBudgetAdvice) a.toJson()],
  };
}

/// Travel between Origin and Destination, both ways.
final class IntercityLeg {
  const IntercityLeg({
    required this.mode,
    required this.durationMin,
    required this.cost,
  });

  factory IntercityLeg.fromJson(Map<String, Object?> json) => IntercityLeg(
    mode: IntercityMode.values.byName(json['mode'] as String),
    durationMin: (json['durationMin'] as num).toInt(),
    cost: (json['cost'] as num).toInt(),
  );

  final IntercityMode mode;

  /// One direction.
  final int durationMin;

  /// Both directions, all travellers.
  final int cost;

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'durationMin': durationMin,
    'cost': cost,
  };
}

/// Which Accommodation the travellers sleep at on one night (1-based).
final class NightStay {
  const NightStay({
    required this.night,
    required this.placeId,
    required this.rooms,
    required this.cost,
  });

  factory NightStay.fromJson(Map<String, Object?> json) => NightStay(
    night: (json['night'] as num).toInt(),
    placeId: json['placeId'] as String,
    rooms: (json['rooms'] as num).toInt(),
    cost: (json['cost'] as num).toInt(),
  );

  final int night;
  final String placeId;
  final int rooms;
  final int cost;

  NightStay copyWith({String? placeId, int? rooms, int? cost}) => NightStay(
    night: night,
    placeId: placeId ?? this.placeId,
    rooms: rooms ?? this.rooms,
    cost: cost ?? this.cost,
  );

  Map<String, Object?> toJson() => {
    'night': night,
    'placeId': placeId,
    'rooms': rooms,
    'cost': cost,
  };
}

/// The ordered Stops of one day.
final class DayPlan {
  const DayPlan({
    required this.date,
    required this.stops,
    this.warnings = const [],
  });

  factory DayPlan.fromJson(Map<String, Object?> json) => DayPlan(
    date: dateFromJson(json['date'] as String),
    stops: [
      for (final s in json['stops'] as List)
        Stop.fromJson(s as Map<String, Object?>),
    ],
    warnings: [
      for (final w in json['warnings'] as List? ?? const []) w as String,
    ],
  );

  final DateTime date;
  final List<Stop> stops;

  /// Thai warnings about the whole day, such as a Stop that was dropped
  /// because its Place was closed (PROJECT-PLAN §10.3).
  final List<String> warnings;

  DayPlan copyWith({List<Stop>? stops}) =>
      DayPlan(date: date, stops: stops ?? this.stops, warnings: warnings);

  Map<String, Object?> toJson() => {
    'date': dateToJson(date),
    'stops': [for (final s in stops) s.toJson()],
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}

/// A visit to one Place within a Day Plan.
final class Stop {
  const Stop({
    required this.placeId,
    required this.slot,
    required this.start,
    required this.durationMin,
    required this.travelFromPrevMin,
    required this.travelFromPrevKm,
    required this.cost,
    this.note,
    this.warnings = const [],
  });

  factory Stop.fromJson(Map<String, Object?> json) => Stop(
    placeId: json['placeId'] as String,
    slot: Slot.values.byName(json['slot'] as String),
    start: ClockTime.parse(json['start'] as String),
    durationMin: (json['durationMin'] as num).toInt(),
    travelFromPrevMin: (json['travelFromPrevMin'] as num).toInt(),
    travelFromPrevKm: (json['travelFromPrevKm'] as num).toDouble(),
    cost: (json['cost'] as num).toInt(),
    note: json['note'] as String?,
    warnings: [
      for (final w in json['warnings'] as List? ?? const []) w as String,
    ],
  );

  final String placeId;
  final Slot slot;
  final ClockTime start;
  final int durationMin;
  final int travelFromPrevMin;
  final double travelFromPrevKm;

  /// Entrance fee or meal cost for all travellers.
  final int cost;

  /// Short reason from Gemini, shown under the Stop.
  final String? note;

  /// Thai messages such as "อาจปิดก่อนไปถึง".
  final List<String> warnings;

  ClockTime get end => start.addMinutes(durationMin);

  Stop copyWith({
    String? placeId,
    Slot? slot,
    ClockTime? start,
    int? durationMin,
    int? travelFromPrevMin,
    double? travelFromPrevKm,
    int? cost,
    String? Function()? note,
    List<String>? warnings,
  }) => Stop(
    placeId: placeId ?? this.placeId,
    slot: slot ?? this.slot,
    start: start ?? this.start,
    durationMin: durationMin ?? this.durationMin,
    travelFromPrevMin: travelFromPrevMin ?? this.travelFromPrevMin,
    travelFromPrevKm: travelFromPrevKm ?? this.travelFromPrevKm,
    cost: cost ?? this.cost,
    note: note != null ? note() : this.note,
    warnings: warnings ?? this.warnings,
  );

  Map<String, Object?> toJson() => {
    'placeId': placeId,
    'slot': slot.name,
    'start': start.toJson(),
    'durationMin': durationMin,
    'travelFromPrevMin': travelFromPrevMin,
    'travelFromPrevKm': travelFromPrevKm,
    'cost': cost,
    if (note != null) 'note': note,
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}
