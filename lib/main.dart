import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/providers/data_providers.dart';
import 'data/hive_trip_repository.dart';
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
  // Saved trips live in a local database until Firestore is set up (#142).
  await Hive.initFlutter();
  final trips = await HiveTripRepository.open();
  final feedback = await Hive.openBox<String>(TasteProfileNotifier.boxName);
  runApp(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(trips),
        placeFeedbackBoxProvider.overrideWithValue(feedback),
      ],
      child: const VayaApp(),
    ),
  );
}
