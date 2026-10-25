import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vaya_app/app/theme/theme_mode_provider.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vaya_settings_');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('theme mode survives a restart', () async {
    Future<ProviderContainer> open() async {
      final box = await Hive.openBox<String>(ThemeModeNotifier.boxName);
      final c = ProviderContainer(
        overrides: [settingsBoxProvider.overrideWithValue(box)],
      );
      addTearDown(c.dispose);
      return c;
    }

    final first = await open();
    expect(first.read(themeModeProvider), ThemeMode.system);
    await first.read(themeModeProvider.notifier).select(ThemeMode.dark);
    await Hive.close();

    final second = await open();
    expect(second.read(themeModeProvider), ThemeMode.dark);
  });

  test('without a box the choice lives in memory', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(themeModeProvider.notifier).select(ThemeMode.light);
    expect(c.read(themeModeProvider), ThemeMode.light);
  });
}
