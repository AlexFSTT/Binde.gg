import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_paths.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/lobby/presentation/lobby_browser_screen.dart';
import '../../features/lobby/presentation/lobby_detail_screen.dart';
import '../../features/match/presentation/match_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../shared/layouts/main_layout.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    // TODO: Add redirect logic for auth guard
    routes: [
      // ── Auth routes (no shell) ──────────────────────
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Main app routes (with shell/sidebar) ────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: Routes.lobbies,
            builder: (context, state) => const LobbyBrowserScreen(),
          ),
          GoRoute(
            path: Routes.lobbyDetail,
            builder: (context, state) => LobbyDetailScreen(
              lobbyId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.matchDetail,
            builder: (context, state) => MatchScreen(
              matchId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, state) => ProfileScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.myProfile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: Routes.leaderboard,
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: Routes.wallet,
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
