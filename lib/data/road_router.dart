import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/domain.dart';

/// The shape of the roads that join points in order, from an OSRM server
/// (ADR-0003). Only for drawing the map: times and distances in the plan
/// still come from `geo.dart`.
class RoadRouter {
  RoadRouter(this._client, {Uri? server})
    : _server = server ?? Uri.parse('https://router.project-osrm.org');

  final http.Client _client;
  final Uri _server;

  /// The road path through [points], or `null` when there is nothing to
  /// route or the server cannot be reached; callers then draw straight
  /// lines.
  Future<List<GeoPoint>?> route(List<GeoPoint> points) async {
    if (points.length < 2) return null;
    final coordinates = points.map((p) => '${p.lng},${p.lat}').join(';');
    try {
      final response = await _client.get(
        _server.replace(
          path: '/route/v1/driving/$coordinates',
          queryParameters: {'overview': 'full', 'geometries': 'geojson'},
        ),
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, Object?>;
      if (json['code'] != 'Ok') return null;
      final route = (json['routes']! as List).first as Map<String, Object?>;
      final geometry = route['geometry']! as Map<String, Object?>;
      return [
        // GeoJSON order is [lng, lat].
        for (final [num lng, num lat, ...] in geometry['coordinates']! as List)
          GeoPoint(lat.toDouble(), lng.toDouble()),
      ];
    } catch (_) {
      // Offline, server error or an unexpected answer.
      return null;
    }
  }
}

/// Points to route, compared by value so a route is fetched once per day.
final class RoutePoints {
  const RoutePoints(this.points);

  final List<GeoPoint> points;

  @override
  bool operator ==(Object other) =>
      other is RoutePoints &&
      other.points.length == points.length &&
      Iterable.generate(
        points.length,
      ).every((i) => other.points[i] == points[i]);

  @override
  int get hashCode => Object.hashAll(points);
}

/// Splits [road], the path through [waypoints] in order, into one leg per
/// pair of neighbouring waypoints (#182). Each leg runs from the road point
/// nearest its start to the one nearest its end, searching forward so a
/// road that passes a waypoint twice still splits in order. Without a road
/// path every leg is the straight line between its two waypoints.
List<List<GeoPoint>> splitIntoLegs(
  List<GeoPoint>? road,
  List<GeoPoint> waypoints,
) {
  if (waypoints.length < 2) return const [];
  if (road == null || road.length < 2) {
    return [
      for (var i = 0; i + 1 < waypoints.length; i++)
        [waypoints[i], waypoints[i + 1]],
    ];
  }
  double distance(GeoPoint a, GeoPoint b) {
    final dLat = a.lat - b.lat, dLng = a.lng - b.lng;
    return dLat * dLat + dLng * dLng;
  }

  final cuts = <int>[0];
  for (var w = 1; w < waypoints.length; w++) {
    final from = cuts.last;
    var best = from;
    for (var i = from; i < road.length; i++) {
      if (distance(road[i], waypoints[w]) <
          distance(road[best], waypoints[w])) {
        best = i;
      }
    }
    cuts.add(w == waypoints.length - 1 ? road.length - 1 : best);
  }
  return [
    for (var i = 0; i + 1 < cuts.length; i++)
      // A leg needs two points even when two waypoints share a road point.
      cuts[i + 1] > cuts[i]
          ? road.sublist(cuts[i], cuts[i + 1] + 1)
          : [road[cuts[i]], road[cuts[i]]],
  ];
}
