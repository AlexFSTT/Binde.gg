import 'package:flutter/material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/match_model.dart';

/// Recent matches section on dashboard.
/// Fetches last 5 matches for the user.
class RecentMatchesSection extends StatefulWidget {
  final String userId;
  const RecentMatchesSection({super.key, required this.userId});

  @override
  State<RecentMatchesSection> createState() => _RecentMatchesSectionState();
}

class _RecentMatchesSectionState extends State<RecentMatchesSection> {
  List<_MatchWithStats>? _matches;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    try {
      final client = SupabaseConfig.client;

      // Fetch recent match_players rows for this user, with match data
      final data = await client
          .from('match_players')
          .select('*, match:matches(*)')
          .eq('player_id', widget.userId)
          .order('joined_at', ascending: false)
          .limit(5);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _matches = data.map((row) {
          final matchJson = row['match'] as Map<String, dynamic>;
          return _MatchWithStats(
            match: MatchModel.fromJson(matchJson),
            team: row['team'] as String,
            kills: row['kills'] as int? ?? 0,
            deaths: row['deaths'] as int? ?? 0,
            assists: row['assists'] as int? ?? 0,
            payout: (row['payout'] as num?)?.toDouble() ?? 0.0,
            eloChange: row['elo_change'] as int? ?? 0,
          );
        }).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent Matches',
      icon: Icons.history_rounded,
      child: _isLoading
          ? const _LoadingState()
          : (_matches == null || _matches!.isEmpty)
              ? const _EmptyState(
                  icon: Icons.sports_esports_outlined,
                  title: 'No matches yet',
                  subtitle: 'Your match history will appear here',
                )
              : Column(
                  children: _matches!
                      .map((m) => _MatchRow(data: m))
                      .toList(),
                ),
    );
  }
}

class _MatchWithStats {
  final MatchModel match;
  final String team;
  final int kills, deaths, assists;
  final double payout;
  final int eloChange;

  _MatchWithStats({
    required this.match,
    required this.team,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.payout,
    required this.eloChange,
  });

  bool get isWin => match.winner == team;
  bool get isLoss => match.winner != null && !isWin;
}

class _MatchRow extends StatelessWidget {
  final _MatchWithStats data;
  const _MatchRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final m = data.match;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          // Win/Loss indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.isWin
                  ? AppColors.successMuted
                  : data.isLoss
                      ? AppColors.dangerMuted
                      : AppColors.bgSurfaceActive,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                data.isWin ? 'W' : data.isLoss ? 'L' : '-',
                style: AppTextStyles.label.copyWith(
                  color: data.isWin
                      ? AppColors.success
                      : data.isLoss
                          ? AppColors.danger
                          : AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Map + mode
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.map ?? 'Unknown Map',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${m.mode} · ${Formatters.timeAgo(m.createdAt)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Score
          Text(
            m.score,
            style: AppTextStyles.mono.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),

          // KDA
          Text(
            Formatters.kda(data.kills, data.deaths, data.assists),
            style: AppTextStyles.mono.copyWith(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),

          // Payout / ELO change
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (data.payout != 0)
                  Text(
                    data.payout > 0
                        ? '+${Formatters.currency(data.payout)}'
                        : Formatters.currency(data.payout),
                    style: AppTextStyles.mono.copyWith(
                      color: data.payout > 0
                          ? AppColors.success
                          : AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (data.eloChange != 0)
                  Text(
                    Formatters.eloChange(data.eloChange),
                    style: AppTextStyles.caption.copyWith(
                      color: data.eloChange > 0
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared section card wrapper.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.textTertiary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(title,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
