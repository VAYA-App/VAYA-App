import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';

// Mock data for building screens before the pipeline (#31) is ready.
// Switch to the real providers as soon as they land, then delete this file.

final mockTripRequestProvider = FutureProvider<TripRequest>((ref) async {
  final json = await rootBundle.loadString(
    'assets/mock/trip_request_demo.json',
  );
  return TripRequest.fromJson(jsonDecode(json) as Map<String, Object?>);
});

final mockTripPlanProvider = FutureProvider<TripPlan>((ref) async {
  final json = await rootBundle.loadString(
    'assets/mock/trip_plan_chonburi_2d.json',
  );
  return TripPlan.fromJson(jsonDecode(json) as Map<String, Object?>);
});
