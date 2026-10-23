import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vaya_app/data/road_router.dart';
import 'package:vaya_app/domain/domain.dart';

const _a = GeoPoint(12.97, 100.89);
const _b = GeoPoint(12.92, 100.87);

String _osrm(List<List<double>> lngLat) => jsonEncode({
  'code': 'Ok',
  'routes': [
    {
      'geometry': {'type': 'LineString', 'coordinates': lngLat},
    },
  ],
});

void main() {
  test('asks OSRM in lng,lat order and reads the GeoJSON path', () async {
    late Uri asked;
    final router = RoadRouter(
      MockClient((request) async {
        asked = request.url;
        return http.Response(
          _osrm([
            [100.89, 12.97],
            [100.88, 12.95],
            [100.87, 12.92],
          ]),
          200,
        );
      }),
    );

    final path = await router.route([_a, _b]);

    expect(asked.host, 'router.project-osrm.org');
    expect(asked.path, '/route/v1/driving/100.89,12.97;100.87,12.92');
    expect(asked.queryParameters, {
      'overview': 'full',
      'geometries': 'geojson',
    });
    expect(path, const [_a, GeoPoint(12.95, 100.88), _b]);
  });

  test('falls back to null on errors, bad answers or one point', () async {
    Future<List<GeoPoint>?> answer(http.Response response) =>
        RoadRouter(MockClient((_) async => response)).route([_a, _b]);

    expect(await answer(http.Response('busy', 503)), isNull);
    expect(
      await answer(http.Response(jsonEncode({'code': 'NoRoute'}), 200)),
      isNull,
    );
    expect(await answer(http.Response('not json', 200)), isNull);
    expect(
      await RoadRouter(
        MockClient((_) async => throw http.ClientException('offline')),
      ).route([_a, _b]),
      isNull,
    );

    var calls = 0;
    final single = RoadRouter(
      MockClient((_) async {
        calls++;
        return http.Response(_osrm([]), 200);
      }),
    );
    expect(await single.route([_a]), isNull);
    expect(calls, 0);
  });

  test('route points compare by value', () {
    expect(const RoutePoints([_a, _b]), const RoutePoints([_a, _b]));
    expect(
      const RoutePoints([_a, _b]).hashCode,
      const RoutePoints([_a, _b]).hashCode,
    );
    expect(const RoutePoints([_a, _b]), isNot(const RoutePoints([_b, _a])));
  });
}
