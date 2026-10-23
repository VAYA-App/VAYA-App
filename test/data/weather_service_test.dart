import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vaya_app/data/weather_service.dart';
import 'package:vaya_app/domain/domain.dart';

const _pattaya = GeoPoint(12.93, 100.88);

String _forecast() => jsonEncode({
  'daily': {
    'time': ['2026-11-14', '2026-11-15'],
    'weather_code': [0, 95],
    'temperature_2m_max': [31.6, 30.2],
    'temperature_2m_min': [25.1, 24.4],
    'precipitation_probability_max': [10, null],
  },
});

void main() {
  Future<List<DayWeather>?> daily(WeatherService service) => service.daily(
    place: _pattaya,
    start: DateTime(2026, 11, 14),
    end: DateTime(2026, 11, 15),
  );

  test('asks Open-Meteo for the trip dates and reads each day', () async {
    late Uri asked;
    final days = await daily(
      WeatherService(
        MockClient((request) async {
          asked = request.url;
          return http.Response(_forecast(), 200);
        }),
      ),
    );

    expect(asked.host, 'api.open-meteo.com');
    expect(asked.path, '/v1/forecast');
    expect(asked.queryParameters, containsPair('latitude', '12.93'));
    expect(asked.queryParameters, containsPair('longitude', '100.88'));
    expect(asked.queryParameters, containsPair('start_date', '2026-11-14'));
    expect(asked.queryParameters, containsPair('end_date', '2026-11-15'));
    expect(asked.queryParameters, containsPair('timezone', 'Asia/Bangkok'));

    expect(days, hasLength(2));
    expect(days!.first.date, DateTime(2026, 11, 14));
    expect(days.first.kind, WeatherKind.clear);
    expect(days.first.maxC, 31.6);
    expect(days.first.rainChance, 10);
    expect(days.last.kind, WeatherKind.storm);
    expect(days.last.rainChance, isNull);
  });

  test('null when out of range, offline or malformed', () async {
    Future<List<DayWeather>?> answer(http.Response response) =>
        daily(WeatherService(MockClient((_) async => response)));

    expect(
      await answer(
        http.Response(
          jsonEncode({'error': true, 'reason': 'out of range'}),
          400,
        ),
      ),
      isNull,
    );
    expect(await answer(http.Response('{}', 200)), isNull);
    expect(
      await daily(
        WeatherService(
          MockClient((_) async => throw http.ClientException('offline')),
        ),
      ),
      isNull,
    );
  });

  test('maps WMO codes to what the sky does', () {
    expect(WeatherKind.fromCode(0), WeatherKind.clear);
    expect(WeatherKind.fromCode(2), WeatherKind.cloudy);
    expect(WeatherKind.fromCode(45), WeatherKind.fog);
    expect(WeatherKind.fromCode(61), WeatherKind.rain);
    expect(WeatherKind.fromCode(81), WeatherKind.rain);
    expect(WeatherKind.fromCode(96), WeatherKind.storm);
  });
}
