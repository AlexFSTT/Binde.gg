import 'package:flutter/material.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/stats_cards_row.dart';
import 'widgets/quick_actions.dart';
import 'widgets/recent_matches_section.dart';
import 'widgets/active_lobbies_section.dart';
import 'widgets/steam_link_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _profileRepo = ProfileRepository();
  final _walletRepo = WalletRepository();

  ProfileModel? _profile;
  WalletModel? _wallet;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Not authenticated';
      });
      return;
    }

    // Fetch profile and wallet in parallel
    final results = await Future.wait([
      _profileRepo.getProfile(userId),
      _walletRepo.getWallet(userId),
    ]);

    if (!mounted) return;

    final profileResult = results[0] as Result<ProfileModel>;
    final walletResult = results[1] as Result<WalletModel>;

    setState(() {
      _isLoading = false;

      if (profileResult.isSuccess) {
        _profile = profileResult.data;
      } else {
        _error = profileResult.error;
      }

      if (walletResult.isSuccess) {
        _wallet = walletResult.data;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Failed to load profile',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDashboardData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome Header ─────────────────────
              DashboardHeader(profile: _profile!),

              const SizedBox(height: 24),

              // ── Steam Link Banner (if no steam) ────
              if (!_profile!.hasSteam) ...[
                const SteamLinkBanner(),
                const SizedBox(height: 24),
              ],

              // ── Stats Cards ────────────────────────
              StatsCardsRow(
                profile: _profile!,
                wallet: _wallet,
              ),

              const SizedBox(height: 28),

              // ── Quick Actions ──────────────────────
              const QuickActions(),

              const SizedBox(height: 28),

              // ── Bottom Grid: Matches + Lobbies ─────
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 800) {
                    // Two columns side by side
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RecentMatchesSection(
                            userId: _profile!.id,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: ActiveLobbiesSection(
                            userId: _profile!.id,
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Stacked for narrow layouts
                    return Column(
                      children: [
                        RecentMatchesSection(userId: _profile!.id),
                        const SizedBox(height: 20),
                        ActiveLobbiesSection(userId: _profile!.id),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
