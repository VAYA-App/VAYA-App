import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/providers/data_providers.dart';
import 'app/theme/theme_mode_provider.dart';
import 'data/firestore_trip_repository.dart';
import 'data/hive_trip_repository.dart';
import 'data/trip_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If Firebase is not yet configured (e.g. google-services.json missing),
    // fallback gracefully to mock repositories.
    debugPrint('Firebase initialization skipped or failed: $e');
  }
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
  // Saved trips go to Firestore where Firebase started (Android, #41) and
  // to the local Hive database everywhere else (#142).
  await Hive.initFlutter();
  final TripRepository trips = Firebase.apps.isEmpty
      ? await HiveTripRepository.open()
      : FirestoreTripRepository(
          currentUid: () => FirebaseAuth.instance.currentUser?.uid,
        );
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
