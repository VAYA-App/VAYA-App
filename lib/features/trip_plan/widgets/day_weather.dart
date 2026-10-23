import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../../data/weather_service.dart';
import '../../../domain/domain.dart';
import '../../trip_request/trip_request_form_notifier.dart';

/// Tests override it so they never hit the network.
final weatherServiceProvider = Provider<WeatherService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return WeatherService(client);
});

typedef WeatherQuery = ({GeoPoint place, DateTime start, DateTime end});

/// The forecast for the whole trip, asked once per trip.
final tripWeatherProvider =
    FutureProvider.family<List<DayWeather>?, WeatherQuery>(
      (ref, q) => ref
          .watch(weatherServiceProvider)
          .daily(place: q.place, start: q.start, end: q.end),
    );

/// One line of forecast for [date] at the destination (#143). Trips too far
/// ahead say when the forecast opens; offline or past trips show nothing.
class DayWeatherRow extends ConsumerWidget {
  const DayWeatherRow({
    super.key,
    required this.place,
    required this.start,
    required this.end,
    required this.date,
  });

  final GeoPoint place;
  final DateTime start;
  final DateTime end;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final lastForecast = today.add(
      const Duration(days: WeatherService.forecastDays - 1),
    );
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    Widget line(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: style)),
      ],
    );

    if (end.isBefore(today)) return const SizedBox.shrink();
    if (start.isAfter(lastForecast)) {
      return line(
        Icons.event_outlined,
        'พยากรณ์อากาศดูได้ล่วงหน้า ${WeatherService.forecastDays} วัน',
      );
    }

    final forecast = ref
        .watch(tripWeatherProvider((place: place, start: start, end: end)))
        .value;
    final day = forecast?.where((d) => d.date == date).firstOrNull;
    if (day == null) return const SizedBox.shrink();
    return line(
      _icons[day.kind]!,
      '${day.kind.label} ${day.maxC.round()}°/${day.minC.round()}°'
      '${day.rainChance == null ? '' : ' · โอกาสฝน ${day.rainChance}%'}',
    );
  }

  static const _icons = {
    WeatherKind.clear: Icons.wb_sunny_outlined,
    WeatherKind.cloudy: Icons.cloud_outlined,
    WeatherKind.fog: Icons.foggy,
    WeatherKind.rain: Icons.umbrella_outlined,
    WeatherKind.storm: Icons.thunderstorm_outlined,
  };
}
