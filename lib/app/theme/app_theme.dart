import 'package:material_ui/material_ui.dart';

/// Material 3 theme for the whole app, styled after the team's Stitch
/// design ("Siam Wanderlust"): emerald primary, warm stone surfaces, white
/// cards and a sunset accent mapped to the tertiary role.
///
/// Screens must read colours and text styles from `Theme.of(context)` only.
/// See docs/DESIGN.md.
abstract final class AppTheme {
  /// Andaman emerald, the brand colour.
  static const Color seedColor = Color(0xFF006948);

  /// Bundled font used for Thai glyphs; Latin text keeps the platform font.
  static const String thaiFontFamily = 'NotoSansThai';

  static ThemeData light() => _build(_lightScheme);

  static ThemeData dark() => _build(_darkScheme);

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(seedColor: seedColor).copyWith(
        primary: seedColor,
        onPrimary: const Color(0xFFFFFFFF),
        // Selection highlights (chips, segmented buttons, navigation) use a
        // soft emerald tint instead of a second hue.
        secondaryContainer: const Color(0xFFD5F0E3),
        onSecondaryContainer: const Color(0xFF005137),
        // Sunset accent for per-person cost, alerts and highlights.
        tertiary: const Color(0xFFA73A00),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: const Color(0xFFFFDBCE),
        onTertiaryContainer: const Color(0xFF370E00),
        surface: const Color(0xFFFFF8F5),
        onSurface: const Color(0xFF1F1B17),
        onSurfaceVariant: const Color(0xFF3D4A42),
        surfaceDim: const Color(0xFFE2D8D2),
        surfaceBright: const Color(0xFFFFF8F5),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFFCF2EB),
        surfaceContainer: const Color(0xFFF6ECE6),
        surfaceContainerHigh: const Color(0xFFF0E6E0),
        surfaceContainerHighest: const Color(0xFFEAE1DA),
        outline: const Color(0xFF6D7A72),
        outlineVariant: const Color(0xFFBCCAC0),
        inverseSurface: const Color(0xFF342F2B),
        onInverseSurface: const Color(0xFFF9EFE8),
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ).copyWith(
        tertiary: const Color(0xFFFFB599),
        onTertiary: const Color(0xFF5A1B00),
        tertiaryContainer: const Color(0xFF7F2B00),
        onTertiaryContainer: const Color(0xFFFFDBCE),
        surface: const Color(0xFF16120F),
        onSurface: const Color(0xFFEAE1DA),
        onSurfaceVariant: const Color(0xFFBCCAC0),
        surfaceContainerLowest: const Color(0xFF110D0A),
        surfaceContainerLow: const Color(0xFF1F1B17),
        surfaceContainer: const Color(0xFF231F1B),
        surfaceContainerHigh: const Color(0xFF2E2925),
        surfaceContainerHighest: const Color(0xFF393430),
        outline: const Color(0xFF87948B),
        outlineVariant: const Color(0xFF3D4A42),
      );

  static ThemeData _build(ColorScheme c) {
    final base = ThemeData(
      colorScheme: c,
      fontFamilyFallback: const [thaiFontFamily],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final text = base.textTheme;
    final soft = BorderSide(color: c.outlineVariant.withValues(alpha: 0.6));
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: c.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: soft,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: c.outlineVariant),
          backgroundColor: c.surfaceContainerLowest,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: soft,
        backgroundColor: c.surfaceContainerLowest,
        selectedColor: c.secondaryContainer,
        labelStyle: text.labelLarge?.copyWith(color: c.onSurface),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.surfaceContainerLowest,
        border: field(c.outlineVariant),
        enabledBorder: field(c.outlineVariant),
        focusedBorder: field(c.primary, 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surfaceContainerLowest,
          selectedBackgroundColor: c.secondaryContainer,
          selectedForegroundColor: c.onSecondaryContainer,
          side: BorderSide(color: c.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceContainerLowest,
        indicatorColor: c.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.secondaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: soft.color, space: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
