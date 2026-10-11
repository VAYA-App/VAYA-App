import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/providers/data_providers.dart';
import 'package:vaya_app/app/router.dart';
import 'package:vaya_app/app/theme/theme_mode_provider.dart';
import 'package:vaya_app/data/auth_repository.dart';

const _user = AppUser(
  uid: 'u1',
  displayName: 'สมใจ ใจดี',
  email: 'somjai@example.com',
);

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._current);

  AppUser? _current;
  final _changes = StreamController<AppUser?>.broadcast();
  int signOutCalls = 0;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    _current = _user;
    _changes.add(_user);
    return _user;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    _changes.add(null);
  }

  void dispose() => _changes.close();
}

/// Real glyph metrics, so layout checks match the device.
Future<void> _loadPromptFont() async {
  final loader = FontLoader('Prompt');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(
      File(
        'assets/fonts/Prompt-$w.ttf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(_loadPromptFont);

  Future<(ProviderContainer, _FakeAuth)> pumpProfile(
    WidgetTester tester, {
    AppUser? user = _user,
    Size size = const Size(412, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = _FakeAuth(user);
    addTearDown(auth.dispose);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    container.read(routerProvider).go(AppRoutes.profile);
    await tester.pumpAndSettle();
    return (container, auth);
  }

  String location(ProviderContainer c) =>
      c.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

  testWidgets('shows the signed-in user', (tester) async {
    await pumpProfile(tester);

    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('ส'), findsOneWidget);
    expect(find.text('สมใจ ใจดี'), findsOneWidget);
    expect(find.text('somjai@example.com'), findsOneWidget);
  });

  testWidgets('changing the theme mode applies to the app at once', (
    tester,
  ) async {
    final (container, _) = await pumpProfile(tester);

    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    await tester.tap(find.text('มืด'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('สมใจ ใจดี'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('signing out asks first, then goes to login for good', (
    tester,
  ) async {
    final (container, auth) = await pumpProfile(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'ออกจากระบบ'),
      ),
    );
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(auth.currentUser, isNull);
    expect(location(container), AppRoutes.login);
    expect(container.read(routerProvider).canPop(), isFalse);
  });

  testWidgets('cancelling the dialog keeps the user signed in', (tester) async {
    final (container, auth) = await pumpProfile(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(auth.signOutCalls, 0);
    expect(location(container), AppRoutes.profile);
  });

  testWidgets('signed out redirects to login', (tester) async {
    final (container, _) = await pumpProfile(tester, user: null);
    expect(location(container), AppRoutes.login);
  });

  for (final (name, size) in [
    ('compact', const Size(360, 800)),
    ('expanded', const Size(1024, 768)),
  ]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('lays out on $name ${mode.name}', (tester) async {
        final (container, _) = await pumpProfile(tester, size: size);
        container.read(themeModeProvider.notifier).select(mode);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('สมใจ ใจดี'), findsOneWidget);
      });
    }
  }

  testWidgets('does not overflow at 200% text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpProfile(tester, size: const Size(360, 800));
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'ออกจากระบบ'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.takeException(), isNull);
  });
}
