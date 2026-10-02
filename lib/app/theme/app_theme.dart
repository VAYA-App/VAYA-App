import 'package:material_ui/material_ui.dart';

/// Material 3 theme for the whole app.
///
/// Screens must read colours and text styles from `Theme.of(context)` only;
/// the seed colour below is the single place where the brand colour lives.
/// See docs/DESIGN.md.
abstract final class AppTheme {
  /// Brand seed used when the platform has no dynamic colour
  /// (iOS and Android below 12).
  static const Color seedColor = Color(0xFF006A6A);

  /// Bundled font used for Thai glyphs; Latin text keeps the platform font.
  static const String thaiFontFamily = 'NotoSansThai';

  static ThemeData light([ColorScheme? dynamicScheme]) =>
      _build(_scheme(Brightness.light, dynamicScheme));

  static ThemeData dark([ColorScheme? dynamicScheme]) =>
      _build(_scheme(Brightness.dark, dynamicScheme));

  // Rebuilding from the dynamic primary gives a complete M3 tonal palette;
  // the schemes reported by some Android versions miss the newer roles.
  static ColorScheme _scheme(
    Brightness brightness,
    ColorScheme? dynamicScheme,
  ) => ColorScheme.fromSeed(
    seedColor: dynamicScheme?.primary ?? seedColor,
    brightness: brightness,
  );

  static ThemeData _build(ColorScheme colorScheme) => ThemeData(
    colorScheme: colorScheme,
    fontFamilyFallback: const [thaiFontFamily],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
