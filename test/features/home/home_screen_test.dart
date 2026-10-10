import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/features/home/greeting.dart';
import 'package:vaya_app/features/trip_request/trip_request_screen.dart';
import 'package:vaya_app/shared/widgets/mascot_view.dart';

void main() {
  test('greets by the time of day', () {
    String title(int hour) => greetingFor(DateTime(2026, 10, 5, hour)).title;

    expect(title(5), 'สวัสดีตอนเช้า');
    expect(title(10), 'สวัสดีตอนเช้า');
    expect(title(11), 'สวัสดีตอนกลางวัน');
    expect(title(16), 'สวัสดีตอนเย็น');
    expect(title(19), 'สวัสดีตอนค่ำ');
    expect(title(23), 'สวัสดีตอนค่ำ');
    expect(title(0), 'ดึกแล้วนะ');
    expect(title(4), 'ดึกแล้วนะ');
  });

  Future<void> pumpHome(WidgetTester tester, {required int hour}) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        greetingClockProvider.overrideWithValue(DateTime(2026, 10, 5, hour)),
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: MockAuthRepository.demoUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(placeCatalogProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the mascot waves next to the greeting', (tester) async {
    await pumpHome(tester, hour: 8);

    expect(find.text('สวัสดีตอนเช้า'), findsOneWidget);
    expect(
      tester.widget<MascotView>(find.byType(MascotView)).pose,
      MascotPose.wave,
    );
  });

  testWidgets('large text fits without the mascot', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHome(tester, hour: 20);

    expect(tester.takeException(), isNull);
    expect(find.text('สวัสดีตอนค่ำ'), findsOneWidget);
    expect(find.byType(MascotView), findsNothing);
  });

  testWidgets('the empty state starts a first trip', (tester) async {
    await pumpHome(tester, hour: 13);

    final start = find.text('เริ่มวางแผนทริปแรก');
    await tester.scrollUntilVisible(start, 200);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.byType(TripRequestScreen), findsOneWidget);
  });
}
