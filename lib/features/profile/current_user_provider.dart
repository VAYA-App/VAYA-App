import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/data_providers.dart';
import '../../data/auth_repository.dart';

/// The signed-in user, or `null` when signed out.
final currentUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
