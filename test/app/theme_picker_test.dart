import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/app.dart';
import 'package:vaya_app/app/theme/app_theme.dart';
import 'package:vaya_app/app/theme/theme_mode_provider.dart';
import 'package:vaya_app/app/theme/theme_palette.dart';

void main() {
  testWidgets('home palette button changes mode and palette', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VayaApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('เปลี่ยนธีม'));
    await tester.pumpAndSettle();
    expect(find.text('ธีมของแอป'), findsOneWidget);

    await tester.tap(find.text('มืด'));
    await tester.tap(find.text('ทะเลคราม'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(container.read(themePaletteProvider), ThemePalette.ocean);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.darkTheme!.colorScheme.primary,
      AppTheme.dark(ThemePalette.ocean).colorScheme.primary,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('ชุดสีทะเลคราม')),
      isSemantics(isSelected: true, isButton: true, hasTapAction: true),
    );
  });

  test('every palette keeps the shared warm surfaces', () {
    for (final palette in ThemePalette.values) {
      expect(
        AppTheme.light(palette).colorScheme.surface,
        const Color(0xFFFFF8F5),
        reason: palette.name,
      );
    }
    expect(AppTheme.light().colorScheme.primary, ThemePalette.emerald.seed);
  });
}
