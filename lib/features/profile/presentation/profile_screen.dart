import 'package:flutter/material.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/profile_repository.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats_grid.dart';
import 'widgets/elo_chart.dart';
import 'widgets/profile_match_history.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileRepo = ProfileRepository();

  ProfileModel? _profile;
  bool _isLoading = true;
  String? _error;

  /// Resolved user ID — either passed in or current user.
  String get _resolvedUserId => (widget.userId == null || widget.userId == 'me')
      ? SupabaseConfig.auth.currentUser!.id
      : widget.userId!;

  bool get _isOwnProfile =>
      widget.userId == null ||
      widget.userId == 'me' ||
      widget.userId == SupabaseConfig.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _profileRepo.getProfile(_resolvedUserId);

    if (!mounted) return;

    result.when(
      success: (profile) => setState(() {
        _profile = profile;
        _isLoading = false;
      }),
      failure: (msg, _) => setState(() {
        _error = msg;
        _isLoading = false;
      }),
    );
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
              const Icon(Icons.person_off_rounded,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                'Player not found',
                style:
                    AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────
            ProfileHeader(
              profile: _profile!,
              isOwnProfile: _isOwnProfile,
            ),

            const SizedBox(height: 28),

            // ── Stats Grid ─────────────────────────
            ProfileStatsGrid(profile: _profile!),

            const SizedBox(height: 28),

            // ── ELO Chart + Match History ──────────
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: EloChart(playerId: _profile!.id),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 4,
                        child: ProfileMatchHistory(
                          playerId: _profile!.id,
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    EloChart(playerId: _profile!.id),
                    const SizedBox(height: 20),
                    ProfileMatchHistory(playerId: _profile!.id),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
