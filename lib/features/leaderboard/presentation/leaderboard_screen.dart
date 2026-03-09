import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/widgets/elo_badge.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _profileRepo = ProfileRepository();
  final _searchCtrl = TextEditingController();

  final List<ProfileModel> _players = [];
  List<ProfileModel>? _searchResults;
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _isLoading = true);

    final result = await _profileRepo.getLeaderboard(
      limit: _pageSize,
      offset: _page * _pageSize,
    );

    if (!mounted) return;

    result.when(
      success: (players) => setState(() {
        _players.addAll(players);
        _page++;
        _hasMore = players.length == _pageSize;
        _isLoading = false;
      }),
      failure: (_, __) => setState(() => _isLoading = false),
    );
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }

    final result = await _profileRepo.searchProfiles(query.trim());
    if (!mounted) return;

    result.when(
      success: (results) => setState(() => _searchResults = results),
      failure: (_, __) {},
    );
  }

  List<ProfileModel> get _displayList => _searchResults ?? _players;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Leaderboard', style: AppTextStyles.h2),
                      const SizedBox(height: 4),
                      Text(
                        'Top players ranked by ELO rating',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),

                // Search
                SizedBox(
                  width: 260,
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: AppTextStyles.bodyMedium,
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'Search player...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.textTertiary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchResults = null);
                              },
                              icon: const Icon(Icons.close_rounded,
                                  size: 16, color: AppColors.textTertiary),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Table Header ───────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  SizedBox(width: 50, child: _colHeader('#')),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _colHeader('PLAYER')),
                  SizedBox(width: 80, child: _colHeader('ELO')),
                  SizedBox(width: 70, child: _colHeader('MATCHES')),
                  SizedBox(width: 70, child: _colHeader('WIN RATE')),
                  SizedBox(width: 60, child: _colHeader('W/L')),
                  SizedBox(width: 70, child: _colHeader('STREAK')),
                  SizedBox(width: 90, child: _colHeader('EARNINGS')),
                ],
              ),
            ),

            // ── Table Body ─────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: _displayList.isEmpty && !_isLoading
                    ? Center(
                        child: Text(
                          _searchResults != null
                              ? 'No players found'
                              : 'No players yet',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textTertiary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _displayList.length +
                            (_hasMore && _searchResults == null ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _displayList.length) {
                            // Load more trigger
                            if (!_isLoading) _loadMore();
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textTertiary),
                                ),
                              ),
                            );
                          }

                          final player = _displayList[i];
                          final rank = _searchResults != null ? null : i + 1;

                          return _PlayerRow(
                            player: player,
                            rank: rank,
                            onTap: () => context.go('/profile/${player.id}'),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colHeader(String text) => Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _PlayerRow extends StatefulWidget {
  final ProfileModel player;
  final int? rank;
  final VoidCallback onTap;

  const _PlayerRow({
    required this.player,
    this.rank,
    required this.onTap,
  });

  @override
  State<_PlayerRow> createState() => _PlayerRowState();
}

class _PlayerRowState extends State<_PlayerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.player;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: _hovered ? AppColors.bgSurfaceHover : AppColors.bgSurface,
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 50,
                child: widget.rank != null
                    ? _RankBadge(rank: widget.rank!)
                    : const SizedBox(),
              ),
              const SizedBox(width: 12),

              // Avatar + Name
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        image: p.steamAvatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(p.steamAvatarUrl!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: p.steamAvatarUrl == null
                          ? Center(
                              child: Text(
                                p.username[0].toUpperCase(),
                                style: AppTextStyles.label.copyWith(
                                    color: AppColors.primary, fontSize: 13),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.username,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ELO
              SizedBox(width: 80, child: EloBadge(elo: p.eloRating)),

              // Matches
              SizedBox(
                width: 70,
                child: Text('${p.matchesPlayed}',
                    style: AppTextStyles.mono.copyWith(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),

              // Win Rate
              SizedBox(
                width: 70,
                child: Text(
                  Formatters.winRate(p.matchesWon, p.matchesPlayed),
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 12,
                    color: p.winRate >= 60
                        ? AppColors.success
                        : p.winRate >= 45
                            ? AppColors.textSecondary
                            : AppColors.danger,
                  ),
                ),
              ),

              // W/L
              SizedBox(
                width: 60,
                child: Text('${p.matchesWon}/${p.matchesLost}',
                    style: AppTextStyles.mono
                        .copyWith(fontSize: 11, color: AppColors.textTertiary)),
              ),

              // Streak
              SizedBox(
                width: 70,
                child: Row(
                  children: [
                    if (p.winStreak > 0)
                      Icon(Icons.local_fire_department_rounded,
                          size: 14, color: AppColors.warning),
                    if (p.winStreak > 0) const SizedBox(width: 4),
                    Text(
                      p.winStreak > 0 ? '${p.winStreak}' : '-',
                      style: AppTextStyles.mono.copyWith(
                        fontSize: 12,
                        color: p.winStreak > 0
                            ? AppColors.warning
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Earnings
              SizedBox(
                width: 90,
                child: Text(
                  Formatters.currency(p.totalEarnings),
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 12,
                    color: p.totalEarnings > 0
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (rank) {
      1 => (const Color(0xFFFFD700), const Color(0xFF2E2A0A)),
      2 => (const Color(0xFFC0C0C0), const Color(0xFF1E1E2E)),
      3 => (const Color(0xFFCD7F32), const Color(0xFF2E1A0A)),
      _ => (AppColors.textTertiary, Colors.transparent),
    };

    if (rank <= 3) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            '#$rank',
            style: AppTextStyles.mono.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      );
    }

    return Text(
      '#$rank',
      style: AppTextStyles.mono.copyWith(
        fontSize: 12,
        color: AppColors.textTertiary,
      ),
    );
  }
}

//
