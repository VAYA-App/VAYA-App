import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme_mode_provider.dart';

/// Whether this device has finished or skipped the intro screens (#178),
/// kept in the same settings box as the theme mode.
final onboardingSeenProvider = NotifierProvider<OnboardingSeenNotifier, bool>(
  OnboardingSeenNotifier.new,
);

class OnboardingSeenNotifier extends Notifier<bool> {
  static const _key = 'onboardingSeen';

  @override
  bool build() => ref.watch(settingsBoxProvider)?.get(_key) == 'true';

  /// The state changes at once; the future completes when it is on disk.
  Future<void> markSeen() async {
    state = true;
    await ref.read(settingsBoxProvider)?.put(_key, 'true');
  }
}
