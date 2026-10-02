import 'package:flutter/widgets.dart';

/// Material 3 window size classes
/// (https://m3.material.io/foundations/layout/applying-layout/window-size-classes).
///
/// Read it with `context.windowSizeClass`; never compare raw widths in screens.
enum WindowSizeClass {
  /// < 600dp: phones in portrait.
  compact,

  /// 600–839dp: tablets in portrait, unfolded foldables.
  medium,

  /// 840–1199dp: tablets in landscape.
  expanded,

  /// 1200–1599dp: desktop-sized windows.
  large,

  /// ≥ 1600dp.
  extraLarge;

  static WindowSizeClass fromWidth(double width) {
    if (width < 600) return compact;
    if (width < 840) return medium;
    if (width < 1200) return expanded;
    if (width < 1600) return large;
    return extraLarge;
  }

  bool isAtLeast(WindowSizeClass other) => index >= other.index;

  /// Horizontal page margin: 16dp on compact, 24dp from medium up.
  double get pageMargin => this == compact ? 16 : 24;

  /// Forms and lists should not stretch wider than this on big windows.
  static const double maxContentWidth = 840;
}

extension WindowSizeClassContext on BuildContext {
  WindowSizeClass get windowSizeClass =>
      WindowSizeClass.fromWidth(MediaQuery.sizeOf(this).width);
}
