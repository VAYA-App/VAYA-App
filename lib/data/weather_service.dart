import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/domain.dart';

/// What the sky does on one day, from a WMO weather code.
enum WeatherKind {
  clear('แดดจัด'),
  cloudy('มีเมฆ'),
  fog('มีหมอก'),
  rain('ฝนตก'),
  storm('ฝนฟ้าคะนอง');

  const WeatherKind(this.label);
  final String label;

  /// WMO 4677 codes as Open-Meteo reports them.
  static WeatherKind fromCode(int code) => switch (code) {
    0 => clear,
    1 || 2 || 3 => cloudy,
    45 || 48 => fog,
    >= 95 => storm,
    _ => rain,
  };
}

/// The forecast for one day of the trip.
final class DayWeather {
  const DayWeather({
    required this.date,
    required this.kind,
    required this.maxC,
    required this.minC,
    this.rainChance,
  });

  final DateTime date;
  final WeatherKind kind;
  final double maxC;
  final double minC;

  /// Percent; `null` when the model gives none.
  final int? rainChance;
}

/// Daily forecasts from Open-Meteo, free and without a key (#143).
class WeatherService {
  WeatherService(this._client, {Uri? server})
    : _server = server ?? Uri.parse('https://api.open-meteo.com');

  /// Open-Meteo forecasts today and the next 15 days.
  static const forecastDays = 16;

  final http.Client _client;
  final Uri _server;

  /// The forecast for every day from [start] to [end] at [place], or `null`
  /// when it cannot be had (offline, server error, dates out of range).
  Future<List<DayWeather>?> daily({
    required GeoPoint place,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _client.get(
        _server.replace(
          path: '/v1/forecast',
          queryParameters: {
            'latitude': '${place.lat}',
            'longitude': '${place.lng}',
            'daily':
                'weather_code,temperature_2m_max,temperature_2m_min,'
                'precipitation_probability_max',
            'timezone': 'Asia/Bangkok',
            'start_date': dateToJson(start),
            'end_date': dateToJson(end),
          },
        ),
      );
      if (response.statusCode != 200) return null;
      final daily =
          (jsonDecode(response.body) as Map<String, Object?>)['daily']!
              as Map<String, Object?>;
      final dates = daily['time']! as List;
      List<Object?> column(String name) => daily[name]! as List;
      return [
        for (var i = 0; i < dates.length; i++)
          DayWeather(
            date: dateFromJson(dates[i]! as String),
            kind: WeatherKind.fromCode(
              (column('weather_code')[i]! as num).toInt(),
            ),
            maxC: (column('temperature_2m_max')[i]! as num).toDouble(),
            minC: (column('temperature_2m_min')[i]! as num).toDouble(),
            rainChance: (column('precipitation_probability_max')[i] as num?)
                ?.toInt(),
          ),
      ];
    } catch (_) {
      // Offline or an unexpected answer.
      return null;
    }
  }
}
