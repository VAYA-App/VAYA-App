import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';

/// Security: nothing but the login screen opens without signing in, and
/// signing out closes the app again (#147).
void main() {
  late ProviderContainer container;
  late MockAuthRepository auth;

  String location() => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;

  Future<void> pumpApp(WidgetTester tester, {bool signedIn = false}) async {
    auth = MockAuthRepository(
      initialUser: signedIn ? MockAuthRepository.demoUser : null,
    );
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    await tester.pump();
  }

  for (final route in [
    AppRoutes.home,
    AppRoutes.explore,
    AppRoutes.myTrips,
    AppRoutes.profile,
    AppRoutes.newTrip,
    AppRoutes.suggestions,
    AppRoutes.tripPlan('mock'),
    AppRoutes.tripPlan('someone-elses-trip'),
  ]) {
    testWidgets('signed out, $route opens the login screen', (tester) async {
      await pumpApp(tester);
      container.read(routerProvider).go(route);
      await tester.pump();

      expect(location(), AppRoutes.login);
    });
  }

  testWidgets('signing out from inside the app returns to login', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true);
    container.read(routerProvider).go(AppRoutes.profile);
    await tester.pump();
    expect(location(), AppRoutes.profile);

    await auth.signOut();
    await tester.pump();
    await tester.pump();

    expect(location(), AppRoutes.login);
  });
}
