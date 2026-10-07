import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/domain/domain.dart';

Map<String, Object?> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  final planJson = readJson('assets/mock/trip_plan_chonburi_2d.json');
  final requestJson = readJson('assets/mock/trip_request_demo.json');

  test('mock trip plan survives a JSON round trip unchanged', () {
    expect(TripPlan.fromJson(planJson).toJson(), equals(planJson));
  });

  test('mock trip request survives a JSON round trip unchanged', () {
    final request = TripRequest.fromJson(requestJson);

    expect(request.toJson(), equals(requestJson));
    expect(request.dayCount, 2);
    expect(request.nightCount, 1);
    expect(request.destinationId, isNull);
  });

  test('saved trip keeps its request and plan', () {
    final trip = Trip(
      ownerUid: 'uid-1',
      createdAt: DateTime.utc(2026, 10, 5),
      updatedAt: DateTime.utc(2026, 10, 5),
      request: TripRequest.fromJson(requestJson),
      plan: TripPlan.fromJson(planJson),
    );

    final copy = Trip.fromJson('trip-1', trip.toJson());

    expect(copy.id, 'trip-1');
    expect(copy.toJson(), equals(trip.toJson()));
  });

  test('mock trip plan costs add up', () {
    final plan = TripPlan.fromJson(planJson);
    final request = TripRequest.fromJson(requestJson);
    final cost = plan.cost;
    final stopCosts = plan.days
        .expand((d) => d.stops)
        .fold<int>(0, (sum, s) => sum + s.cost);

    // Breakfast is food that belongs to no Stop; the exact split is checked
    // in test/planner/cost_calculator_test.dart.
    expect(stopCosts, lessThanOrEqualTo(cost.food + cost.entrance));
    expect(
      plan.nightStays.fold<int>(0, (sum, n) => sum + n.cost),
      cost.accommodation,
    );
    expect(plan.intercity!.cost, cost.intercity);
    expect(
      cost.intercity +
          cost.accommodation +
          cost.food +
          cost.entrance +
          cost.localTransport +
          cost.buffer,
      cost.total,
    );
    expect(cost.perPerson, (cost.total / request.travellerCount).ceil());
    expect(cost.isOverBudget, plan.status == PlanStatus.overBudget);
  });
}
