import '../domain/domain.dart';

/// Starting prices behind every Cost Estimate, loaded from
/// `assets/data/pricing.json` (PROJECT-PLAN §9, docs/DATA.md). Intercity
/// fares and tolls are per route and live in `provinces.json` instead.
final class PricingTable {
  const PricingTable({
    required this.roomPerNight,
    required this.mealPerPerson,
    required this.breakfastPerPerson,
    required this.localTransport,
    required this.selfDrivePerKm,
    required this.bufferRate,
  });

  factory PricingTable.fromJson(Map<String, Object?> json) {
    final rates = json['localTransport'] as Map<String, Object?>;
    return PricingTable(
      roomPerNight: _byPriceLevel(json, 'roomPerNight'),
      mealPerPerson: _byPriceLevel(json, 'mealPerPerson'),
      breakfastPerPerson: (json['breakfastPerPerson'] as num).toInt(),
      localTransport: {
        for (final mode in LocalTransportMode.values)
          mode: switch (rates[mode.name]) {
            final Map<String, Object?> rate => LocalTransportRate.fromJson(
              rate,
            ),
            _ => throw FormatException('Missing localTransport', mode.name),
          },
      },
      selfDrivePerKm: (json['selfDrivePerKm'] as num).toDouble(),
      bufferRate: (json['bufferRate'] as num).toDouble(),
    );
  }

  /// Baht per room per night, keyed by Price Level 1–4.
  final Map<int, int> roomPerNight;

  /// Baht per person per meal, keyed by the Restaurant's Price Level 1–4.
  final Map<int, int> mealPerPerson;

  /// Baht per person for a morning the Accommodation does not cover.
  final int breakfastPerPerson;
  final Map<LocalTransportMode, LocalTransportRate> localTransport;

  /// Fuel per kilometre when the Intercity Transport is the traveller's car.
  final double selfDrivePerKm;

  /// Share of every other category kept as contingency, e.g. `0.1`.
  final double bufferRate;

  int roomFor(int priceLevel) => roomPerNight[priceLevel]!;
  int mealFor(int priceLevel) => mealPerPerson[priceLevel]!;
  LocalTransportRate rateFor(LocalTransportMode mode) => localTransport[mode]!;

  static Map<int, int> _byPriceLevel(Map<String, Object?> json, String key) {
    final prices = json[key] as Map<String, Object?>;
    return {
      for (var level = 1; level <= 4; level++)
        level: switch (prices['$level']) {
          final num price => price.toInt(),
          _ => throw FormatException('Missing $key', '$level'),
        },
    };
  }
}

/// How one Local Transport Mode is charged. A mode uses only the parts it
/// needs; the rest stay zero.
final class LocalTransportRate {
  const LocalTransportRate({
    this.perDay = 0,
    this.perTrip = 0,
    this.perKm = 0,
    this.capacity,
  });

  factory LocalTransportRate.fromJson(Map<String, Object?> json) =>
      LocalTransportRate(
        perDay: (json['perDay'] as num?)?.toInt() ?? 0,
        perTrip: (json['perTrip'] as num?)?.toInt() ?? 0,
        perKm: (json['perKm'] as num?)?.toDouble() ?? 0,
        capacity: (json['capacity'] as num?)?.toInt(),
      );

  /// Rental fee for each day of the trip.
  final int perDay;

  /// Flat fare for each leg.
  final int perTrip;
  final double perKm;

  /// Travellers that fit in one vehicle. `null` means every traveller pays
  /// their own fare (public transport).
  final int? capacity;

  /// How many times the rate is charged for [travellerCount] people:
  /// vehicles needed, or travellers when there is no shared vehicle.
  int unitsFor(int travellerCount) => switch (capacity) {
    final int seats => (travellerCount / seats).ceil(),
    null => travellerCount,
  };
}
