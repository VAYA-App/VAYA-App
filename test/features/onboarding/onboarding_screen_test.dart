import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/features/onboarding/onboarding_seen_provider.dart';
import 'package:vaya_app/shared/widgets/mascot_view.dart';

void main() {
  Future<ProviderContainer> pumpOnboarding(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Signed out: the intro comes before signing in.
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    container.read(routerProvider).go(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    return container;
  }

  String location(ProviderContainer c) =>
      c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

  MascotPose pose(WidgetTester tester) =>
      tester.widget<MascotView>(find.byType(MascotView)).pose;

  testWidgets('three pages, then marks it seen and goes to sign in', (
    tester,
  ) async {
    final c = await pumpOnboarding(tester);
    expect(location(c), AppRoutes.onboarding);
    expect(pose(tester), MascotPose.calendar);
    expect(find.bySemanticsLabel('หน้า 1 จาก 3'), findsOneWidget);

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();
    expect(pose(tester), MascotPose.map);

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();
    expect(pose(tester), MascotPose.celebrate);
    expect(find.text('ข้าม'), findsNothing);
    expect(c.read(onboardingSeenProvider), isFalse);

    await tester.tap(find.text('เริ่มเลย'));
    await tester.pumpAndSettle();
    expect(c.read(onboardingSeenProvider), isTrue);
    expect(location(c), AppRoutes.login);
  });

  testWidgets('skip goes straight to sign in', (tester) async {
    final c = await pumpOnboarding(tester);

    await tester.tap(find.text('ข้าม'));
    await tester.pumpAndSettle();
    expect(c.read(onboardingSeenProvider), isTrue);
    expect(location(c), AppRoutes.login);
  });
}
