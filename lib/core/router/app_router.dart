import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_paths.dart';
import 'dock_page_transition.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/lobby/presentation/lobby_browser_screen.dart';
import '../../features/lobby/presentation/lobby_detail_screen.dart';
import '../../features/match/presentation/match_screen.dart';
import '../../features/play/presentation/play_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/teams/presentation/teams_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/shop/presentation/shop_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../shared/layouts/dock_layout.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    routes: [
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (context, state) => const RegisterScreen()),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => DockLayout(child: child),
        routes: [
          GoRoute(path: Routes.dashboard, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const DashboardScreen())),
          GoRoute(path: Routes.lobbies, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const LobbyBrowserScreen())),
          GoRoute(path: Routes.lobbyDetail, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: LobbyDetailScreen(lobbyId: s.pathParameters['id']!))),
          GoRoute(path: Routes.play, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const PlayScreen())),
          GoRoute(path: Routes.matchDetail, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: MatchScreen(matchId: s.pathParameters['id']!))),
          GoRoute(path: Routes.leaderboard, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const LeaderboardScreen())),
          GoRoute(path: Routes.subscription, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const SubscriptionScreen())),
          GoRoute(path: Routes.teams, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const TeamsScreen())),
          GoRoute(path: Routes.profile, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: ProfileScreen(userId: s.pathParameters['id']!))),
          GoRoute(path: Routes.myProfile, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const ProfileScreen())),
          GoRoute(path: Routes.wallet, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const WalletScreen())),
          GoRoute(path: Routes.shop, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const ShopScreen())),
          GoRoute(path: Routes.settings, pageBuilder: (c, s) => DockPageTransition(key: s.pageKey, child: const SettingsScreen())),
        ],
      ),
    ],
  );
}
