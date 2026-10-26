import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/app/theme/app_theme.dart';
import 'package:vaya_app/data/auth_repository.dart';
import 'package:vaya_app/data/mock/mock_auth_repository.dart';
import 'package:vaya_app/features/auth/google_logo.dart';
import 'package:vaya_app/features/auth/login_screen.dart';
import 'package:vaya_app/features/home/home_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AppUser? initialUser, this.onSignIn})
    : _user = initialUser;

  AppUser? _user;
  final Future<AppUser> Function()? onSignIn;
  final _controller = StreamController<AppUser?>.broadcast();
  int signInCallCount = 0;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    signInCallCount++;
    if (onSignIn != null) {
      final user = await onSignIn!();
      _user = user;
      _controller.add(user);
      return user;
    }
    _user = MockAuthRepository.demoUser;
    _controller.add(_user);
    return MockAuthRepository.demoUser;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  Widget buildTestSubject({
    required AuthRepository authRepository,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen UI & Material 3 components', () {
    testWidgets(
      'shows logo, app name, description, and google sign-in button',
      (tester) async {
        final auth = _FakeAuthRepository();
        addTearDown(auth.dispose);

        await tester.pumpWidget(buildTestSubject(authRepository: auth));
        await tester.pumpAndSettle();

        expect(find.text('VAYA'), findsOneWidget);
        expect(find.text('เที่ยวไทยแบบ\nไม่ต้องวางแผนเอง'), findsOneWidget);
        expect(
          find.text('AI จัดแผนรายวัน ค่าใช้จ่าย และเส้นทางบนแผนที่ให้ในไม่กี่วินาที'),
          findsOneWidget,
        );
        expect(find.byType(GoogleLogo), findsOneWidget);
        expect(
          find.text('ทริปที่บันทึกจะซิงก์กับบัญชีนี้ทุกเครื่อง'),
          findsOneWidget,
        );
        expect(find.text('ข้อกำหนด'), findsOneWidget);
        expect(find.text('นโยบายความเป็นส่วนตัว'), findsOneWidget);

        final buttonFinder = find.widgetWithText(
          FilledButton,
          'เข้าสู่ระบบด้วย Google',
        );
        expect(buttonFinder, findsOneWidget);
      },
    );

    testWidgets('tapping sign in button invokes signInWithGoogle', (
      tester,
    ) async {
      final auth = _FakeAuthRepository();
      addTearDown(auth.dispose);

      await tester.pumpWidget(buildTestSubject(authRepository: auth));
      await tester.pumpAndSettle();

      expect(auth.signInCallCount, 0);
      await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
      await tester.pumpAndSettle();

      expect(auth.signInCallCount, 1);
    });

    testWidgets('shows loading progress and disables button while signing in', (
      tester,
    ) async {
      final completer = Completer<AppUser>();
      final auth = _FakeAuthRepository(onSignIn: () => completer.future);
      addTearDown(auth.dispose);

      await tester.pumpWidget(buildTestSubject(authRepository: auth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
      await tester.pump();

      // Progress indicator should be visible and button disabled
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'เข้าสู่ระบบด้วย Google'),
      );
      expect(button.onPressed, isNull);

      completer.complete(MockAuthRepository.demoUser);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows SnackBar when sign-in fails with AuthException', (
      tester,
    ) async {
      final auth = _FakeAuthRepository(
        onSignIn: () => Future.error(
          const AuthException('เครือข่ายขัดข้อง กรุณาลองใหม่อีกครั้ง'),
        ),
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(buildTestSubject(authRepository: auth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('เครือข่ายขัดข้อง กรุณาลองใหม่อีกครั้ง'),
        findsOneWidget,
      );
    });

    testWidgets('does not show SnackBar when sign-in is cancelled by user', (
      tester,
    ) async {
      final auth = _FakeAuthRepository(
        onSignIn: () => Future.error(
          const AuthException('ผู้ใช้ยกเลิกการเลือกบัญชี', cancelled: true),
        ),
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(buildTestSubject(authRepository: auth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('Auth redirect with GoRouter', () {
    testWidgets(
      'unauthenticated access to deep link /trips/test-id redirects to /login',
      (tester) async {
        final auth = _FakeAuthRepository();
        addTearDown(auth.dispose);

        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const VayaApp(),
          ),
        );
        container.read(routerProvider).go('/trips/test-id');
        await tester.pumpAndSettle();

        final currentUri = container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .toString();
        expect(currentUri, AppRoutes.login);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets('signing in immediately redirects to home route /', (
      tester,
    ) async {
      final auth = _FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const VayaApp()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.tap(find.text('เข้าสู่ระบบด้วย Google'));
      await tester.pumpAndSettle();

      final currentUri = container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();
      expect(currentUri, AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Responsive & Accessibility', () {
    for (final (modeName, mode) in [
      ('Light', ThemeMode.light),
      ('Dark', ThemeMode.dark),
    ]) {
      for (final (sizeName, size) in [
        ('Compact', const Size(360, 640)),
        ('Expanded', const Size(1024, 768)),
      ]) {
        testWidgets('renders cleanly on $sizeName $modeName without overflow', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final auth = _FakeAuthRepository();
          addTearDown(auth.dispose);

          await tester.pumpWidget(
            buildTestSubject(authRepository: auth, themeMode: mode),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(LoginScreen), findsOneWidget);
        });
      }
    }

    testWidgets('renders without overflow at 200% font scaling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = _FakeAuthRepository();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: const LoginScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
