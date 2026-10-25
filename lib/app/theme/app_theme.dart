import 'package:material_ui/material_ui.dart';

/// Material 3 theme for the whole app, "Emerald Field Guide": one green
/// family for every accent role, mint-tinted surfaces and white cards. Only
/// the error roles leave the green family, so Over Budget still stands out.
///
/// Screens must read colours and text styles from `Theme.of(context)` only.
/// See docs/DESIGN.md.
abstract final class AppTheme {
  /// Andaman emerald, the brand colour.
  static const Color seedColor = Color(0xFF006948);

  /// Bundled Prompt font, covering both Thai and Latin.
  static const String fontFamily = 'Prompt';

  static ThemeData light() => _build(_light);

  static ThemeData dark() => _build(_dark);

  static final ColorScheme _light = ColorScheme.fromSeed(seedColor: seedColor)
      .copyWith(
        primary: seedColor,
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFF9CF2C6),
        onPrimaryContainer: const Color(0xFF002114),
        inversePrimary: const Color(0xFF6FDBA8),
        // Selection highlights (chips, segmented buttons, navigation).
        secondaryContainer: const Color(0xFFD5F0E3),
        onSecondaryContainer: const Color(0xFF0E3B28),
        // Lime accent for per-person cost, in-budget and tips.
        tertiary: const Color(0xFF3D6A00),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: const Color(0xFFC6F08E),
        onTertiaryContainer: const Color(0xFF0F2000),
        surface: const Color(0xFFF6FBF7),
        onSurface: const Color(0xFF161D19),
        onSurfaceVariant: const Color(0xFF3F4944),
        surfaceDim: const Color(0xFFD6DBD7),
        surfaceBright: const Color(0xFFF6FBF7),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFEEF5F0),
        surfaceContainer: const Color(0xFFE8F0EA),
        surfaceContainerHigh: const Color(0xFFE2EBE4),
        surfaceContainerHighest: const Color(0xFFDCE5DE),
        outline: const Color(0xFF6F7973),
        outlineVariant: const Color(0xFFBFC9C2),
        inverseSurface: const Color(0xFF2B322E),
        onInverseSurface: const Color(0xFFECF2ED),
      );

  static final ColorScheme _dark =
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF6FDBA8),
        onPrimary: const Color(0xFF003824),
        primaryContainer: const Color(0xFF005236),
        onPrimaryContainer: const Color(0xFF8BF8C3),
        inversePrimary: seedColor,
        secondaryContainer: const Color(0xFF2A4A3A),
        onSecondaryContainer: const Color(0xFFC2EED7),
        tertiary: const Color(0xFFA9D475),
        onTertiary: const Color(0xFF1D3700),
        tertiaryContainer: const Color(0xFF2C5000),
        onTertiaryContainer: const Color(0xFFC6F08E),
        surface: const Color(0xFF0E1511),
        onSurface: const Color(0xFFDDE4DE),
        onSurfaceVariant: const Color(0xFFBFC9C2),
        surfaceDim: const Color(0xFF0E1511),
        surfaceBright: const Color(0xFF343B37),
        surfaceContainerLowest: const Color(0xFF09100C),
        surfaceContainerLow: const Color(0xFF161D19),
        surfaceContainer: const Color(0xFF1A211D),
        surfaceContainerHigh: const Color(0xFF242C27),
        surfaceContainerHighest: const Color(0xFF2F3732),
        outline: const Color(0xFF89938C),
        outlineVariant: const Color(0xFF3F4944),
        inverseSurface: const Color(0xFFDDE4DE),
        onInverseSurface: const Color(0xFF2B322E),
      );

  static ThemeData _build(ColorScheme c) {
    final base = ThemeData(
      colorScheme: c,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final text = _textTheme(base.textTheme);
    final soft = BorderSide(color: c.outlineVariant.withValues(alpha: 0.6));
    // Cards, fields and bars sit above the background: white in light mode,
    // a lighter tone in dark mode (where the lowest container is darkest).
    final raised = c.brightness == Brightness.light
        ? c.surfaceContainerLowest
        : c.surfaceContainerHigh;
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: c.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: raised,
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
          backgroundColor: raised,
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
        backgroundColor: raised,
        selectedColor: c.secondaryContainer,
        labelStyle: text.labelLarge?.copyWith(color: c.onSurface),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: raised,
        border: field(c.outlineVariant),
        enabledBorder: field(c.outlineVariant),
        focusedBorder: field(c.primary, 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: raised,
          selectedBackgroundColor: c.secondaryContainer,
          selectedForegroundColor: c.onSecondaryContainer,
          side: BorderSide(color: c.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: raised,
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
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: soft.color, space: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Stitch type rhythm: semi-bold headlines, light body text and open line
  /// heights so Thai tone marks never collide. Only weights and heights are
  /// set here; Flutter adds the font sizes for the locale's script later.
  static TextTheme _textTheme(TextTheme t) {
    const semiBold = FontWeight.w600, medium = FontWeight.w500;
    return t.copyWith(
      displaySmall: t.displaySmall?.copyWith(fontWeight: semiBold),
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: semiBold),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: semiBold),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: semiBold),
      titleLarge: t.titleLarge?.copyWith(fontWeight: semiBold),
      titleMedium: t.titleMedium?.copyWith(fontWeight: medium),
      titleSmall: t.titleSmall?.copyWith(fontWeight: medium),
      bodyLarge: t.bodyLarge?.copyWith(
        fontWeight: FontWeight.w300,
        height: 1.6,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        fontWeight: FontWeight.w300,
        height: 1.55,
      ),
      bodySmall: t.bodySmall?.copyWith(height: 1.5),
      labelLarge: t.labelLarge?.copyWith(fontWeight: medium),
      labelMedium: t.labelMedium?.copyWith(fontWeight: medium),
    );
  }
}
