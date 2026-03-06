import 'package:flutter/material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/match_model.dart';

/// Match history section for the profile page.
/// Fetches match_players joined with matches.
class ProfileMatchHistory extends StatefulWidget {
  final String playerId;
  const ProfileMatchHistory({super.key, required this.playerId});

  @override
  State<ProfileMatchHistory> createState() => _ProfileMatchHistoryState();
}

class _ProfileMatchHistoryState extends State<ProfileMatchHistory> {
  final List<_MatchEntry> _matches = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final client = SupabaseConfig.client;
      final from = _page * _pageSize;

      final data = await client
          .from('match_players')
          .select('*, match:matches(*)')
          .eq('player_id', widget.playerId)
          .order('joined_at', ascending: false)
          .range(from, from + _pageSize - 1);

      if (!mounted) return;

      final entries = data.map((row) {
        final matchJson = row['match'] as Map<String, dynamic>;
        return _MatchEntry(
          match: MatchModel.fromJson(matchJson),
          team: row['team'] as String,
          kills: row['kills'] as int? ?? 0,
          deaths: row['deaths'] as int? ?? 0,
          assists: row['assists'] as int? ?? 0,
          adr: (row['adr'] as num?)?.toDouble() ?? 0.0,
          hltvRating: (row['hltv_rating'] as num?)?.toDouble() ?? 0.0,
          payout: (row['payout'] as num?)?.toDouble() ?? 0.0,
          eloChange: row['elo_change'] as int? ?? 0,
        );
      }).toList();

      setState(() {
        _isLoading = false;
        _matches.addAll(entries);
        _page++;
        _hasMore = entries.length == _pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                const Icon(Icons.history_rounded,
                    size: 18, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(
                  'Match History',
                  style: AppTextStyles.label.copyWith(fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${_matches.length} matches',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Table header
          if (_matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const SizedBox(width: 40), // result indicator
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text('MAP',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8)),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text('SCORE',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('K/D/A',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8)),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('ADR',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8)),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('HLTV',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('ELO',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8)),
                  ),
                ],
              ),
            ),

          // Matches list
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _matches.isEmpty && !_isLoading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.sports_esports_outlined,
                              size: 40,
                              color: AppColors.textTertiary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No matches yet',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('Match history will appear here',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      ..._matches.map((e) => _MatchRow(entry: e)),

                      // Load more / loading
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        )
                      else if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: TextButton(
                              onPressed: _loadMore,
                              child: Text(
                                'Load more',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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

class _MatchEntry {
  final MatchModel match;
  final String team;
  final int kills, deaths, assists;
  final double adr, hltvRating, payout;
  final int eloChange;

  _MatchEntry({
    required this.match,
    required this.team,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.adr,
    required this.hltvRating,
    required this.payout,
    required this.eloChange,
  });

  bool get isWin => match.winner == team;
  bool get isLoss => match.winner != null && !isWin;
}

class _MatchRow extends StatelessWidget {
  final _MatchEntry entry;
  const _MatchRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final m = entry.match;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          // W/L indicator
          Container(
            width: 36,
            height: 30,
            decoration: BoxDecoration(
              color: entry.isWin
                  ? AppColors.successMuted
                  : entry.isLoss
                      ? AppColors.dangerMuted
                      : AppColors.bgSurfaceActive,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                entry.isWin ? 'W' : entry.isLoss ? 'L' : '-',
                style: AppTextStyles.label.copyWith(
                  fontSize: 12,
                  color: entry.isWin
                      ? AppColors.success
                      : entry.isLoss
                          ? AppColors.danger
                          : AppColors.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Map + mode + time
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.map ?? 'Unknown',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${m.mode} · ${Formatters.timeAgo(m.createdAt)}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),

          // Score
          SizedBox(
            width: 60,
            child: Text(
              m.score,
              style: AppTextStyles.mono.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // KDA
          SizedBox(
            width: 70,
            child: Text(
              Formatters.kda(entry.kills, entry.deaths, entry.assists),
              style: AppTextStyles.mono.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // ADR
          SizedBox(
            width: 50,
            child: Text(
              entry.adr.toStringAsFixed(1),
              style: AppTextStyles.mono.copyWith(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),

          // HLTV Rating
          SizedBox(
            width: 50,
            child: Text(
              entry.hltvRating.toStringAsFixed(2),
              style: AppTextStyles.mono.copyWith(
                fontSize: 12,
                color: _ratingColor(entry.hltvRating),
              ),
            ),
          ),

          // ELO change
          SizedBox(
            width: 70,
            child: Text(
              entry.eloChange != 0
                  ? Formatters.eloChange(entry.eloChange)
                  : '-',
              textAlign: TextAlign.right,
              style: AppTextStyles.mono.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: entry.eloChange > 0
                    ? AppColors.success
                    : entry.eloChange < 0
                        ? AppColors.danger
                        : AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _ratingColor(double rating) {
    if (rating >= 1.3) return AppColors.success;
    if (rating >= 1.0) return AppColors.textSecondary;
    if (rating >= 0.8) return AppColors.warning;
    return AppColors.danger;
  }
}
