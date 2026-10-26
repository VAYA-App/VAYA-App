import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/providers/data_providers.dart';
import 'app/theme/theme_mode_provider.dart';
import 'data/hive_trip_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind transparent system bars and let SafeArea and NavigationBar
  // pad for them, so Android's navigation buttons never cover the app's own
  // buttons (#180).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarDividerColor: Color(0x00000000),
      systemNavigationBarContrastEnforced: false,
    ),
  );
  // Saved trips live in a local database until Firestore is set up (#142).
  await Hive.initFlutter();
  final trips = await HiveTripRepository.open();
  final feedback = await Hive.openBox<String>(TasteProfileNotifier.boxName);
  final settings = await Hive.openBox<String>(ThemeModeNotifier.boxName);
  runApp(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(trips),
        placeFeedbackBoxProvider.overrideWithValue(feedback),
        settingsBoxProvider.overrideWithValue(settings),
      ],
      child: const VayaApp(),
    ),
  );
}
