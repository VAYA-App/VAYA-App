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
