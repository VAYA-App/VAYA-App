import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/data/weather_service.dart';
import 'package:vaya_app/domain/domain.dart';
import 'package:vaya_app/features/trip_plan/widgets/day_weather.dart';
import 'package:vaya_app/features/trip_request/trip_request_form_notifier.dart';

class _FakeWeather implements WeatherService {
  _FakeWeather(this.days);

  final List<DayWeather>? days;
  var calls = 0;

  @override
  Future<List<DayWeather>?> daily({
    required GeoPoint place,
    required DateTime start,
    required DateTime end,
  }) async {
    calls++;
    return days;
  }
}

void main() {
  final start = DateTime(2026, 11, 14);
  final end = DateTime(2026, 11, 15);

  Future<_FakeWeather> pumpRow(
    WidgetTester tester, {
    required DateTime today,
    List<DayWeather>? days,
    DateTime? date,
  }) async {
    final weather = _FakeWeather(days);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherServiceProvider.overrideWithValue(weather),
          todayProvider.overrideWithValue(today),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DayWeatherRow(
              place: const GeoPoint(12.93, 100.88),
              start: start,
              end: end,
              date: date ?? start,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return weather;
  }

  final forecast = [
    DayWeather(
      date: DateTime(2026, 11, 14),
      kind: WeatherKind.clear,
      maxC: 31.6,
      minC: 25.1,
      rainChance: 10,
    ),
    DayWeather(
      date: DateTime(2026, 11, 15),
      kind: WeatherKind.rain,
      maxC: 29.4,
      minC: 24.6,
    ),
  ];

  testWidgets('shows the forecast of its day', (tester) async {
    await pumpRow(tester, today: DateTime(2026, 11, 10), days: forecast);
    expect(find.text('แดดจัด 32°/25° · โอกาสฝน 10%'), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);

    await pumpRow(
      tester,
      today: DateTime(2026, 11, 10),
      days: forecast,
      date: end,
    );
    expect(find.text('ฝนตก 29°/25°'), findsOneWidget);
  });

  testWidgets('too far ahead: says when, without asking', (tester) async {
    final weather = await pumpRow(tester, today: DateTime(2026, 10, 23));

    expect(find.text('พยากรณ์อากาศดูได้ล่วงหน้า 16 วัน'), findsOneWidget);
    expect(weather.calls, 0);
  });

  testWidgets('offline: nothing', (tester) async {
    await pumpRow(tester, today: DateTime(2026, 11, 10));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a past trip: nothing, without asking', (tester) async {
    final weather = await pumpRow(tester, today: DateTime(2026, 12, 1));
    expect(find.byType(Text), findsNothing);
    expect(weather.calls, 0);
  });
}
