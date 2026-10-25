import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

/// Device settings such as the theme mode. `main.dart` overrides it with a
/// Hive box; `null` keeps settings in memory, as in tests.
final settingsBoxProvider = Provider<Box<String>?>((ref) => null);

/// The theme mode chosen on the profile screen, remembered across launches.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const boxName = 'settings';
  static const _key = 'themeMode';

  @override
  ThemeMode build() {
    final saved = ref.watch(settingsBoxProvider)?.get(_key);
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
  }

  /// The state changes at once; the future completes when it is on disk.
  Future<void> select(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsBoxProvider)?.put(_key, mode.name);
  }
}
