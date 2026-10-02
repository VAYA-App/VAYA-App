import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/generating/generating_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/suggestion/suggestion_screen.dart';
import '../features/trip_plan/trip_plan_screen.dart';
import '../features/trip_request/trip_request_screen.dart';
import 'layout/adaptive_shell.dart';

/// Every location in the app. Use these instead of string literals.
abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const profile = '/profile';
  static const newTrip = '/new-trip';
  static const suggestions = '/new-trip/suggestions';
  static const generating = '/new-trip/generating';
  static String tripPlan(String tripId) => '/trips/$tripId';
}

/// Auth redirect is added by #15.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveShell(navigationShell: navigationShell),
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
            builder: (context, state) => const GeneratingScreen(),
          ),
        ],
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
