import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/planner/pricing_table.dart';

Map<String, Object?> _pricingJson() =>
    jsonDecode(File('assets/data/pricing.json').readAsStringSync())
        as Map<String, Object?>;

void main() {
  group('assets/data/pricing.json', () {
    late PricingTable table;

    setUp(() => table = PricingTable.fromJson(_pricingJson()));

    test('prices rooms and meals for every Price Level', () {
      expect(table.roomPerNight, {1: 700, 2: 1500, 3: 3000, 4: 6000});
      expect(table.mealPerPerson, {1: 80, 2: 200, 3: 450, 4: 1000});
      expect(table.roomFor(3), 3000);
      expect(table.mealFor(1), 80);
    });

    test('carries breakfast, self-drive and buffer rates', () {
      expect(table.breakfastPerPerson, 100);
      expect(table.selfDrivePerKm, 2.5);
      expect(table.bufferRate, 0.1);
    });

    test('has a rate for every Local Transport Mode', () {
      expect(table.localTransport.keys, LocalTransportMode.values);

      final car = table.rateFor(LocalTransportMode.rentalCar);
      expect(
        (car.perDay, car.perTrip, car.perKm, car.capacity),
        (1000, 0, 2.5, 4),
      );

      final bike = table.rateFor(LocalTransportMode.rentalMotorbike);
      expect(
        (bike.perDay, bike.perTrip, bike.perKm, bike.capacity),
        (250, 0, 1.0, 2),
      );

      final taxi = table.rateFor(LocalTransportMode.taxi);
      expect(
        (taxi.perDay, taxi.perTrip, taxi.perKm, taxi.capacity),
        (0, 40, 12.0, 4),
      );

      final public = table.rateFor(LocalTransportMode.publicTransport);
      expect(
        (public.perDay, public.perTrip, public.perKm, public.capacity),
        (0, 30, 0.0, null),
      );
    });
  });

  group('PricingTable.fromJson', () {
    test('rejects a table with a missing Price Level', () {
      final json = _pricingJson();
      (json['roomPerNight'] as Map<String, Object?>).remove('4');

      expect(() => PricingTable.fromJson(json), throwsFormatException);
    });

    test('rejects a table with a missing Local Transport Mode', () {
      final json = _pricingJson();
      (json['localTransport'] as Map<String, Object?>).remove('taxi');

      expect(() => PricingTable.fromJson(json), throwsFormatException);
    });
  });

  group('LocalTransportRate.unitsFor', () {
    test('counts vehicles when travellers share one', () {
      const car = LocalTransportRate(capacity: 4);
      expect([1, 4, 5, 8, 9].map(car.unitsFor), [1, 1, 2, 2, 3]);

      const bike = LocalTransportRate(capacity: 2);
      expect([1, 2, 3, 5].map(bike.unitsFor), [1, 1, 2, 3]);
    });

    test('counts travellers when everyone pays their own fare', () {
      const public = LocalTransportRate(perTrip: 30);
      expect([1, 2, 3, 5].map(public.unitsFor), [1, 2, 3, 5]);
    });
  });
}
