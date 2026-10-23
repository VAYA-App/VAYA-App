import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/providers/data_providers.dart';
import 'data/hive_trip_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Saved trips live in a local database until Firestore is set up (#142).
  await Hive.initFlutter();
  final trips = await HiveTripRepository.open();
  runApp(
    ProviderScope(
      overrides: [tripRepositoryProvider.overrideWithValue(trips)],
      child: const VayaApp(),
    ),
  );
}
