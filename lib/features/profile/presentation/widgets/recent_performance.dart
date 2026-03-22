import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/match_model.dart';

/// FACEIT-style "Recent Performance" section for player profile.
/// Shows aggregate stats from last 30 matches + ELO chart + match list.
class RecentPerformance extends StatefulWidget {
  final String playerId;
  final int currentElo;
  final int eloPeak;
  final int bestWinStreak;

  const RecentPerformance({
    super.key,
    required this.playerId,
    required this.currentElo,
    required this.eloPeak,
    required this.bestWinStreak,
  });

  @override
  State<RecentPerformance> createState() => _RecentPerformanceState();
}

class _RecentPerformanceState extends State<RecentPerformance> {
  final _client = SupabaseConfig.client;

  List<_MatchEntry> _matches = [];
  List<_EloPoint> _eloPoints = [];
  bool _isLoading = true;

  // Aggregate stats (computed from last 30 matches)
  int _wins = 0, _losses = 0;
  int _totalKills = 0, _totalDeaths = 0, _totalAssists = 0, _totalHeadshots = 0;
  double _avgAdr = 0;
  int _totalEloChange = 0;
  int _currentStreak = 0; // positive = wins, negative = losses

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Step 1: Get this player's match_players rows (simple query, no join)
      final mpData = await _client
          .from('match_players')
          .select()
          .eq('player_id', widget.playerId)
          .order('joined_at', ascending: false)
          .limit(50);

      if (!mounted) return;
      debugPrint(
          '[RecentPerformance] match_players rows: ${(mpData as List).length}');
      if ((mpData as List).isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Step 2: Get the match IDs and fetch matches separately
      final matchIds =
          mpData.map((row) => row['match_id'] as String).toSet().toList();

      final matchesData = await _client
          .from('matches')
          .select()
          .inFilter('id', matchIds)
          .eq('status', 'finished');

      if (!mounted) return;

      // Build a lookup map: matchId → match data
      final matchMap = <String, Map<String, dynamic>>{};
      for (final m in (matchesData as List)) {
        matchMap[m['id'] as String] = m;
      }
      debugPrint(
          '[RecentPerformance] finished matches found: ${matchMap.length}');

      // Step 3: Fetch ELO history
      final eloData = await _client
          .from('elo_history')
          .select('elo_after, created_at')
          .eq('player_id', widget.playerId)
          .order('created_at', ascending: true)
          .limit(50);

      if (!mounted) return;

      // Step 4: Build entries (only for finished matches)
      final entries = <_MatchEntry>[];
      int wins = 0, losses = 0;
      int kills = 0, deaths = 0, assists = 0, headshots = 0;
      double adrSum = 0;
      int eloChange = 0;

      for (final row in mpData) {
        final matchId = row['match_id'] as String;
        final matchJson = matchMap[matchId];
        if (matchJson == null) continue; // Not a finished match

        final match = MatchModel.fromJson(matchJson);
        final team = row['team'] as String;
        final isWin = match.winner == team;

        final entry = _MatchEntry(
          match: match,
          team: team,
          kills: row['kills'] as int? ?? 0,
          deaths: row['deaths'] as int? ?? 0,
          assists: row['assists'] as int? ?? 0,
          headshots: row['headshots'] as int? ?? 0,
          adr: (row['adr'] as num?)?.toDouble() ?? 0,
          eloChange: row['elo_change'] as int? ?? 0,
          isWin: isWin,
        );

        entries.add(entry);
        if (isWin) {
          wins++;
        } else {
          losses++;
        }
        kills += entry.kills;
        deaths += entry.deaths;
        assists += entry.assists;
        headshots += entry.headshots;
        adrSum += entry.adr;
        eloChange += entry.eloChange;

        if (entries.length >= 30) break;
      }

      debugPrint(
          '[RecentPerformance] entries built: ${entries.length}, kills=$kills, deaths=$deaths');

      // Current streak (from most recent)
      int streak = 0;
      if (entries.isNotEmpty) {
        final firstWin = entries.first.isWin;
        for (final e in entries) {
          if (e.isWin == firstWin) {
            streak++;
          } else {
            break;
          }
        }
        if (!firstWin) streak = -streak;
      }

      final eloPoints = eloData
          .map((e) => _EloPoint(
                elo: e['elo_after'] as int,
                date: DateTime.parse(e['created_at'] as String),
              ))
          .toList();

      setState(() {
        _matches = entries;
        _eloPoints = eloPoints;
        _wins = wins;
        _losses = losses;
        _totalKills = kills;
        _totalDeaths = deaths;
        _totalAssists = assists;
        _totalHeadshots = headshots;
        _avgAdr = entries.isEmpty ? 0 : adrSum / entries.length;
        _totalEloChange = eloChange;
        _currentStreak = streak;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('[RecentPerformance] ERROR: $e');
      debugPrint('[RecentPerformance] Stack: $st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _winRate =>
      (_wins + _losses) == 0 ? 0 : _wins / (_wins + _losses) * 100;
  double get _avgKd =>
      _totalDeaths == 0 ? _totalKills.toDouble() : _totalKills / _totalDeaths;
  double get _hsRate =>
      _totalKills == 0 ? 0 : _totalHeadshots / _totalKills * 100;
  int get _avgKills =>
      _matches.isEmpty ? 0 : (_totalKills / _matches.length).round();
  int get _avgDeaths =>
      _matches.isEmpty ? 0 : (_totalDeaths / _matches.length).round();
  int get _avgAssists =>
      _matches.isEmpty ? 0 : (_totalAssists / _matches.length).round();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section title ───────────────────────
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Recent Performance', style: AppTextStyles.h3),
            const SizedBox(width: 8),
            Text('Last ${_matches.length} Matches',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary)),
          ],
        ),
        const SizedBox(height: 16),

        // ── Stat boxes (top row) ───────────────
        _buildStatBoxes(),

        const SizedBox(height: 16),

        // ── ELO chart + Summary panel ──────────
        _buildEloSection(),

        const SizedBox(height: 16),

        // ── Win/Loss streak bar ─────────────────
        if (_matches.isNotEmpty) ...[
          _buildStreakBar(),
          const SizedBox(height: 20),
        ],

        // ── Last matches table ─────────────────
        _buildMatchTable(),
      ],
    );
  }

  Widget _buildStatBoxes() {
    final stats = [
      _StatBox('Win %', '${_winRate.toStringAsFixed(0)}%',
          _winRate >= 50 ? AppColors.success : AppColors.danger),
      _StatBox('K / D / A', '$_avgKills / $_avgDeaths / $_avgAssists',
          AppColors.textPrimary),
      _StatBox('K/D', _avgKd.toStringAsFixed(2),
          _avgKd >= 1.0 ? AppColors.success : AppColors.warning),
      _StatBox('HS%', '${_hsRate.toStringAsFixed(0)}%', AppColors.accent),
      _StatBox('ADR', _avgAdr.toStringAsFixed(1), AppColors.info),
    ];

    return Row(
      children: stats
          .map((s) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: s == stats.last ? 0 : 10),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.value,
                          style: AppTextStyles.mono.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: s.color)),
                      const SizedBox(height: 2),
                      Text(s.label,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildEloSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ELO Chart
        Expanded(
          flex: 3,
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: _eloPoints.length < 2
                ? Center(
                    child: Text('Not enough data for chart',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary)))
                : CustomPaint(
                    size: const Size(double.infinity, 168),
                    painter: _EloChartPainter(points: _eloPoints),
                  ),
          ),
        ),
        const SizedBox(width: 12),

        // Summary panel
        SizedBox(
          width: 200,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // W / L record
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _wlBadge('W', _wins, AppColors.success),
                    const SizedBox(width: 8),
                    Text('/',
                        style: AppTextStyles.h3
                            .copyWith(color: AppColors.textTertiary)),
                    const SizedBox(width: 8),
                    _wlBadge('L', _losses, AppColors.danger),
                  ],
                ),
                const SizedBox(height: 16),

                // ELO display
                Center(
                  child: Text('${widget.currentElo}',
                      style: AppTextStyles.mono.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                const SizedBox(height: 12),

                // ELO change
                _summaryRow(
                    'Elo change',
                    _totalEloChange >= 0
                        ? '+$_totalEloChange'
                        : '$_totalEloChange',
                    _totalEloChange >= 0
                        ? AppColors.success
                        : AppColors.danger),
                const SizedBox(height: 8),

                // Peak ELO
                _summaryRow('Peak ELO', '${widget.eloPeak}', AppColors.accent),
                const SizedBox(height: 8),

                // Win streak
                _summaryRow(
                  'Current streak',
                  _currentStreak > 0
                      ? '${_currentStreak}W'
                      : '${_currentStreak.abs()}L',
                  _currentStreak > 0 ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(height: 8),

                _summaryRow(
                    'Best streak', '${widget.bestWinStreak}', AppColors.accent),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _wlBadge(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
          child: Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10)),
        ),
        const SizedBox(width: 6),
        Text('$count',
            style: AppTextStyles.mono.copyWith(
                fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
        Text(value,
            style: AppTextStyles.mono.copyWith(
                fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _buildStreakBar() {
    return SizedBox(
      height: 10,
      child: Row(
        children: _matches.reversed.map((m) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: m.isWin ? AppColors.success : AppColors.danger,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMatchTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text('Last Matches',
                    style: AppTextStyles.label.copyWith(fontSize: 13)),
                const Spacer(),
                Text('${_matches.length} matches',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),

          // Column headers
          Container(
            color: AppColors.bgSurfaceActive,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _th('Date', width: 90),
                _th('Score', width: 80),
                _th('KDA', width: 80),
                _th('ADR', width: 50),
                _th('K/D', width: 50),
                _th('HS%', width: 50),
                Expanded(
                  child: Text('Map',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),

          // Rows
          ...(_matches.take(10).map((m) => _MatchRow(entry: m))),

          if (_matches.length > 10)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text('+${_matches.length - 10} more matches',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _th(String label, {double? width}) {
    return SizedBox(
      width: width,
      child: Text(label,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textTertiary, letterSpacing: 0.5)),
    );
  }
}

// ── Supporting classes ──────────────────────────────────────

class _StatBox {
  final String label, value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);
}

class _MatchEntry {
  final MatchModel match;
  final String team;
  final int kills, deaths, assists, headshots, eloChange;
  final double adr;
  final bool isWin;

  const _MatchEntry({
    required this.match,
    required this.team,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.headshots,
    required this.adr,
    required this.eloChange,
    required this.isWin,
  });

  double get kd => deaths == 0 ? kills.toDouble() : kills / deaths;
  double get hsRate => kills == 0 ? 0 : headshots / kills * 100;
}

class _EloPoint {
  final int elo;
  final DateTime date;
  const _EloPoint({required this.elo, required this.date});
}

// ── Match table row ─────────────────────────────────────────

class _MatchRow extends StatelessWidget {
  final _MatchEntry entry;
  const _MatchRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final m = entry.match;
    final scoreA = m.teamAScore;
    final scoreB = m.teamBScore;
    final myScore = entry.team == 'team_a' ? scoreA : scoreB;
    final enemyScore = entry.team == 'team_a' ? scoreB : scoreA;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: entry.isWin ? AppColors.success : AppColors.danger,
            width: 3,
          ),
          bottom: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Formatters.date(m.createdAt),
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),

          // Score
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: entry.isWin ? AppColors.success : AppColors.danger,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(entry.isWin ? 'W' : 'L',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Text('$myScore',
                    style: AppTextStyles.mono.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: entry.isWin
                            ? AppColors.success
                            : AppColors.textPrimary)),
                Text(' : $enemyScore',
                    style: AppTextStyles.mono
                        .copyWith(fontSize: 13, color: AppColors.textTertiary)),
              ],
            ),
          ),

          // KDA
          SizedBox(
            width: 80,
            child: Text('${entry.kills} / ${entry.deaths} / ${entry.assists}',
                style: AppTextStyles.mono
                    .copyWith(fontSize: 11, color: AppColors.textSecondary)),
          ),

          // ADR
          SizedBox(
            width: 50,
            child: Text(entry.adr.toStringAsFixed(1),
                style: AppTextStyles.mono
                    .copyWith(fontSize: 11, color: AppColors.textTertiary)),
          ),

          // K/D
          SizedBox(
            width: 50,
            child: Text(entry.kd.toStringAsFixed(2),
                style: AppTextStyles.mono.copyWith(
                    fontSize: 11,
                    color: entry.kd >= 1.0
                        ? AppColors.textSecondary
                        : AppColors.warning)),
          ),

          // HS%
          SizedBox(
            width: 50,
            child: Text('${entry.hsRate.toStringAsFixed(0)}%',
                style: AppTextStyles.mono
                    .copyWith(fontSize: 11, color: AppColors.textTertiary)),
          ),

          // Map
          Expanded(
            child: Text(m.map ?? '-',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── ELO Chart Painter ───────────────────────────────────────

class _EloChartPainter extends CustomPainter {
  final List<_EloPoint> points;
  const _EloChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minElo = points.map((p) => p.elo).reduce(min) - 20;
    final maxElo = points.map((p) => p.elo).reduce(max) + 20;
    final range = (maxElo - minElo).clamp(1, double.infinity);

    final linePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accent.withValues(alpha: 0.25),
          AppColors.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    // Draw grid lines
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      final elo = maxElo - (range * i / 3);
      final tp = TextPainter(
        text: TextSpan(
          text: '${elo.round()}',
          style: TextStyle(
              color: AppColors.textTertiary.withValues(alpha: 0.5),
              fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height - 2));
    }

    // Build path
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height - (size.height * (points[i].elo - minElo) / range);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw last point dot
    if (points.isNotEmpty) {
      final lastX = size.width;
      final lastY =
          size.height - (size.height * (points.last.elo - minElo) / range);
      canvas.drawCircle(
          Offset(lastX, lastY), 4, Paint()..color = AppColors.accent);
      canvas.drawCircle(
          Offset(lastX, lastY), 2, Paint()..color = AppColors.bgSurface);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
