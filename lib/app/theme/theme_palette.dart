import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Colour palettes the user can pick (#71). Each one seeds a full M3
/// scheme; emerald is the brand palette from the Stitch design.
enum ThemePalette {
  emerald('มรกต', Color(0xFF006948)),
  ocean('ทะเลคราม', Color(0xFF00639B)),
  sunset('ส้มพระอาทิตย์', Color(0xFFC2410C)),
  orchid('ชมพูกล้วยไม้', Color(0xFF8E3A8C));

  const ThemePalette(this.label, this.seed);

  final String label;
  final Color seed;
}

/// The palette chosen by the user; kept for the session only.
final themePaletteProvider =
    NotifierProvider<ThemePaletteNotifier, ThemePalette>(
      ThemePaletteNotifier.new,
    );

class ThemePaletteNotifier extends Notifier<ThemePalette> {
  @override
  ThemePalette build() => ThemePalette.emerald;

  void select(ThemePalette palette) => state = palette;
}
