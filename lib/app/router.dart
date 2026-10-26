import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository.dart';
import 'providers/data_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/explore/place_detail_screen.dart';
import '../features/generating/generating_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/photo_credits_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/suggestion/suggestion_screen.dart';
import '../features/trip_plan/trip_plan_screen.dart';
import '../features/trip_request/trip_request_screen.dart';
import '../features/trips/my_trips_screen.dart';
import 'layout/adaptive_shell.dart';

/// Every location in the app. Use these instead of string literals.
abstract final class AppRoutes {
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const explore = '/explore';
  static const myTrips = '/trips';
  static const profile = '/profile';
  static const newTrip = '/new-trip';
  static const suggestions = '/new-trip/suggestions';
  static const generating = '/new-trip/generating';
  static const photoCredits = '/photo-credits';
  static String tripPlan(String tripId) => '/trips/$tripId';
  static String place(String placeId) => '/places/$placeId';
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<AppUser?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AppUser?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Auth redirect based on auth state (#15).
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final refreshNotifier = _AuthRefreshNotifier(
    authRepository.authStateChanges(),
  );
  ref.onDispose(refreshNotifier.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // The intro screens come before signing in (#178).
      if (state.matchedLocation == AppRoutes.onboarding) return null;
      final loggedIn = authRepository.currentUser != null;
      final loggingIn = state.matchedLocation == AppRoutes.login;

      // ยังไม่ล็อกอิน → /login
      if (!loggedIn) {
        return loggingIn ? null : AppRoutes.login;
      }

      // ล็อกอินแล้วแต่อยู่ที่ /login → /
      if (loggingIn) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveShell(navigationShell: navigationShell),
        // Order matches the tabs in AdaptiveShell.
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myTrips,
                builder: (context, state) => const MyTripsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.newTrip,
        builder: (context, state) => const TripRequestScreen(),
        routes: [
          GoRoute(
            path: 'suggestions',
            builder: (context, state) => const SuggestionScreen(),
          ),
          GoRoute(
            path: 'generating',
            builder: (context, state) => GeneratingScreen(
              destinationId: state.uri.queryParameters['destination'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/places/:placeId',
        builder: (context, state) =>
            PlaceDetailScreen(placeId: state.pathParameters['placeId']!),
      ),
      GoRoute(
        path: AppRoutes.photoCredits,
        builder: (context, state) => const PhotoCreditsScreen(),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) =>
            TripPlanScreen(tripId: state.pathParameters['tripId']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
