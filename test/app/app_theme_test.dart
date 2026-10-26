import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/theme/app_theme.dart';

void main() {
  double hue(Color c) => HSVColor.fromColor(c).hue;

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    test('$name accents all stay in the green family', () {
      final c = theme.colorScheme;
      for (final accent in [
        c.primary,
        c.primaryContainer,
        c.secondaryContainer,
        c.tertiary,
        c.tertiaryContainer,
      ]) {
        expect(hue(accent), inInclusiveRange(80, 170), reason: '$accent');
      }
      // Over Budget must still read as a warning.
      expect(hue(c.error), anyOf(lessThan(30), greaterThan(330)));
    });
  }

  test('light primary is the brand emerald on mint surfaces', () {
    final c = AppTheme.light().colorScheme;
    expect(c.primary, AppTheme.seedColor);
    expect(c.surface, const Color(0xFFF6FBF7));
    expect(c.surfaceContainerLowest, const Color(0xFFFFFFFF));
  });
}
