import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/logger.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/match_model.dart';
import '../../../data/repositories/match_repository.dart';
import '../../../services/realtime/realtime_service.dart';
import '../../../services/sound/sound_service.dart';
import '../../../shared/widgets/status_badge.dart';
import 'veto_screen.dart';
import '../../../shared/widgets/glass_card.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  const MatchScreen({super.key, required this.matchId});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final _matchRepo = MatchRepository();
  final _realtime = RealtimeService();
  final _client = SupabaseConfig.client;

  MatchModel? _match;
  List<_MatchPlayer> _players = [];
  bool _isLoading = true;
  bool _isProvisioning = false;
  bool _isLobbyCreator = false;
  String? _provisionError;

  @override
  void initState() {
    super.initState();
    Log.d('MatchScreen initState for match: ${widget.matchId}');
    _loadMatch();
  }

  @override
  void dispose() {
    _realtime.unsubscribe('match:${widget.matchId}');
    super.dispose();
  }

  Future<void> _loadMatch() async {
    Log.d('_loadMatch() called');
    setState(() => _isLoading = true);

    final result = await _matchRepo.getMatch(widget.matchId);
    if (!mounted) return;

    if (result.isSuccess) {
      await _loadPlayers();
      await _checkIfCreator();

      setState(() {
        _match = result.data;
        _isLoading = false;
      });

      Log.d(
          'Match loaded - status: ${_match!.status}, map: ${_match!.map}, connect: ${_match!.connectString}, isCreator: $_isLobbyCreator');

      _subscribeRealtime();
      _checkAndProvision();
    } else {
      Log.e('Failed to load match: ${result.error}');
      setState(() => _isLoading = false);
    }
  }

  /// FIX #2: Check if current user is the lobby creator
  Future<void> _checkIfCreator() async {
    if (_match?.lobbyId == null) {
      // If loaded from result.data, _match might not be set yet. Check DB directly.
      try {
        final matchData = await _client
            .from('matches')
            .select('lobby_id')
            .eq('id', widget.matchId)
            .single();

        final lobbyId = matchData['lobby_id'] as String?;
        if (lobbyId != null) {
          final lobbyData = await _client
              .from('lobbies')
              .select('created_by')
              .eq('id', lobbyId)
              .single();

          _isLobbyCreator =
              lobbyData['created_by'] == SupabaseConfig.auth.currentUser?.id;
        }
      } catch (_) {
        _isLobbyCreator = false;
      }
    }
    Log.d('Is lobby creator: $_isLobbyCreator');
  }

  /// FIX #2: Only lobby creator triggers provisioning
  void _checkAndProvision() {
    if (_match == null) return;

    Log.d(
        '_checkAndProvision: status=${_match!.status}, connect=${_match!.connectString}, isCreator=$_isLobbyCreator, provisioning=$_isProvisioning');

    if (_match!.status == 'ready_check' &&
        _match!.connectString == null &&
        _isLobbyCreator &&
        !_isProvisioning) {
      Log.d('>>> TRIGGERING PROVISION (creator only)');
      _provisionServer();
    }
  }

  Future<void> _loadPlayers() async {
    try {
      final data = await _client
          .from('match_players')
          .select(
              '*, profile:profiles(id, username, elo_rating, steam_avatar_url)')
          .eq('match_id', widget.matchId);

      if (!mounted) return;

      setState(() {
        _players = data.map((row) {
          final profile = row['profile'] as Map<String, dynamic>;
          return _MatchPlayer(
            id: profile['id'] as String,
            username: profile['username'] as String,
            elo: profile['elo_rating'] as int? ?? 100,
            avatarUrl: profile['steam_avatar_url'] as String?,
            team: row['team'] as String,
            kills: row['kills'] as int? ?? 0,
            deaths: row['deaths'] as int? ?? 0,
            assists: row['assists'] as int? ?? 0,
            adr: (row['adr'] as num?)?.toDouble() ?? 0,
            hltvRating: (row['hltv_rating'] as num?)?.toDouble() ?? 0,
            payout: (row['payout'] as num?)?.toDouble() ?? 0,
            eloChange: row['elo_change'] as int? ?? 0,
          );
        }).toList();
      });
    } catch (e) {
      Log.e('Failed to load players', error: e);
    }
  }

  void _subscribeRealtime() {
    Log.d('Subscribing to realtime for match: ${widget.matchId}');

    _realtime.subscribeMatch(
      matchId: widget.matchId,
      onMatchUpdate: (data) {
        if (!mounted) return;

        final updated = MatchModel.fromJson(data);
        final oldStatus = _match?.status;
        final oldConnectString = _match?.connectString;

        Log.d(
            'Realtime: $oldStatus → ${updated.status}, connect: ${updated.connectString}');

        setState(() => _match = updated);
        _loadPlayers();

        // FIX #2: All players detect connect_string via realtime
        if (updated.connectString != null && _isProvisioning) {
          Log.d('Connect string received via realtime!');
          setState(() {
            _isProvisioning = false;
            _provisionError = null;
          });
        }

        // Play match ready sound when server is ready (1v1 and 2v2 only)
        if (updated.connectString != null &&
            oldConnectString == null &&
            (updated.mode == '1v1' || updated.mode == '2v2')) {
          SoundService.playMatchReady();
        }

        // Veto just completed → only creator provisions
        if (oldStatus == 'veto' && updated.status == 'ready_check') {
          Log.d('Veto completed, checking provision...');
          _checkAndProvision();
        }
      },
      onVeto: (data) {
        Log.d('Veto event: ${data['map_name']}');
      },
    );
  }

  Future<void> _provisionServer() async {
    if (_isProvisioning) return;

    Log.d('>>> _provisionServer() START');

    setState(() {
      _isProvisioning = true;
      _provisionError = null;
    });

    try {
      final response = await _client.functions.invoke(
        'provision-server',
        body: {'match_id': widget.matchId},
      );

      Log.d(
          '>>> Edge function response: ${response.status} - ${response.data}');

      if (!mounted) return;

      if (response.status != 200) {
        final errorData = response.data;
        final errorMsg = errorData is Map
            ? (errorData['error'] ?? 'Provisioning failed')
            : 'Status ${response.status}';
        Log.e('Provision failed: $errorMsg');
        setState(() {
          _isProvisioning = false;
          _provisionError = errorMsg.toString();
        });
      }
    } catch (e, stack) {
      Log.e('Provision exception', error: e, stack: stack);
      if (mounted) {
        setState(() {
          _isProvisioning = false;
          _provisionError = 'Failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgBase,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_match == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
          const SizedBox(height: 16),
          Text('Match not found', style: AppTextStyles.h3),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Back to Dashboard')),
        ])),
      );
    }

    // Veto phase
    if (_match!.status == 'veto') {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: MapVetoScreen(
          matchId: widget.matchId,
          onVetoComplete: () {
            Log.d('VetoScreen signaled completion, reloading...');
            _loadMatch();
          },
        ),
      );
    }

    final m = _match!;
    final teamA = _players.where((p) => p.team == 'team_a').toList();
    final teamB = _players.where((p) => p.team == 'team_b').toList();

    return GlassPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              IconButton(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Text('Match', style: AppTextStyles.h2),
              const SizedBox(width: 12),
              _matchStatusBadge(m.status),
              if (m.map != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.bgSurfaceActive,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(m.map!,
                      style: AppTextStyles.mono.copyWith(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
              const Spacer(),
              Text(
                  '${m.mode} · ${m.entryFee > 0 ? "Pot: ${Formatters.currency(m.totalPot)}" : "Free"}',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textTertiary)),
            ]),

            const SizedBox(height: 28),

            // FIX #2: Provisioning/waiting state for ALL players
            if (m.connectString == null && m.status == 'ready_check') ...[
              if (_isProvisioning || _isLobbyCreator)
                _ProvisioningCard()
              else
                _WaitingForServerCard(),
              if (_provisionError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _ProvisionErrorCard(
                      error: _provisionError!, onRetry: _provisionServer),
                ),
              const SizedBox(height: 28),
            ],

            // Connect info — visible to ALL players
            if (m.connectString != null && !m.isLive && !m.isFinished) ...[
              _ConnectCard(connectString: m.connectString!),
              const SizedBox(height: 28),
            ],

            // Scoreboard
            _ScoreHeader(match: m),
            const SizedBox(height: 24),

            // Stats
            if (_players.isNotEmpty) ...[
              _StatsTable(
                  label: 'TEAM A',
                  color: const Color(0xFF3498DB),
                  players: teamA),
              const SizedBox(height: 16),
              _StatsTable(
                  label: 'TEAM B',
                  color: const Color(0xFFE74C3C),
                  players: teamB),
            ],

            // Result
            if (m.isFinished) ...[
              const SizedBox(height: 28),
              _MatchResultCard(match: m),
            ],
          ],
        ),
      ),
    );
  }

  Widget _matchStatusBadge(String status) => switch (status) {
        'veto' => const StatusBadge(label: 'VETO', color: AppColors.info),
        'ready_check' =>
          const StatusBadge(label: 'SERVER', color: AppColors.warning),
        'live' => StatusBadge.live(),
        'finished' => StatusBadge.finished(),
        'cancelled' =>
          const StatusBadge(label: 'CANCELLED', color: AppColors.textTertiary),
        _ => StatusBadge(
            label: status.toUpperCase(), color: AppColors.textTertiary),
      };
}

// ═══════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════

class _MatchPlayer {
  final String id, username, team;
  final int elo, kills, deaths, assists, eloChange;
  final double adr, hltvRating, payout;
  final String? avatarUrl;
  const _MatchPlayer(
      {required this.id,
      required this.username,
      required this.team,
      required this.elo,
      this.avatarUrl,
      this.kills = 0,
      this.deaths = 0,
      this.assists = 0,
      this.adr = 0,
      this.hltvRating = 0,
      this.payout = 0,
      this.eloChange = 0});
}

class _ProvisioningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withValues(alpha: 0.08),
          AppColors.bgSurface
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: AppColors.primary)),
        const SizedBox(height: 20),
        Text('Setting up CS2 server...',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('This takes 15-30 seconds. Server powerd by Hetzner.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

/// FIX #2: Non-creator players see this while waiting
class _WaitingForServerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.info.withValues(alpha: 0.06),
          AppColors.bgSurface
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: AppColors.info)),
        const SizedBox(height: 20),
        Text('Waiting for server...',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(
            'The lobby creator is setting up the CS2 server. You will see the connect info automatically.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _ProvisionErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ProvisionErrorCard({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.dangerMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
      child: Column(children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.danger, size: 32),
        const SizedBox(height: 12),
        Text('Server provisioning failed',
            style: AppTextStyles.label.copyWith(color: AppColors.danger)),
        const SizedBox(height: 8),
        Text(error,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger)),
      ]),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  final String connectString;
  const _ConnectCard({required this.connectString});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.success.withValues(alpha: 0.08),
            AppColors.bgSurface
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
      child: Column(children: [
        const Icon(Icons.dns_rounded, color: AppColors.success, size: 32),
        const SizedBox(height: 12),
        Text('SERVER READY',
            style: AppTextStyles.label
                .copyWith(color: AppColors.success, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.bgSurfaceActive,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SelectableText(connectString,
                  style: AppTextStyles.mono
                      .copyWith(fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(width: 12),
              IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: connectString));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Copied to clipboard!'),
                        duration: Duration(seconds: 1)));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: AppColors.primary,
                  tooltip: 'Copy'),
            ])),
        const SizedBox(height: 12),
        Text('Open CS2 console (~) and paste the command above',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textTertiary)),
      ]),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  final MatchModel match;
  const _ScoreHeader({required this.match});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(
            child: Column(children: [
          Text('TEAM A',
              style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFF3498DB), letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text('${match.teamAScore}',
              style: AppTextStyles.monoLarge.copyWith(
                  fontSize: 48,
                  color: match.winner == 'team_a'
                      ? AppColors.success
                      : AppColors.textPrimary)),
        ])),
        Column(children: [
          Text('VS',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textTertiary, fontSize: 16)),
          if (match.map != null) ...[
            const SizedBox(height: 4),
            Text(match.map!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary))
          ],
        ]),
        Expanded(
            child: Column(children: [
          Text('TEAM B',
              style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFFE74C3C), letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text('${match.teamBScore}',
              style: AppTextStyles.monoLarge.copyWith(
                  fontSize: 48,
                  color: match.winner == 'team_b'
                      ? AppColors.success
                      : AppColors.textPrimary)),
        ])),
      ]),
    );
  }
}

class _StatsTable extends StatelessWidget {
  final String label;
  final Color color;
  final List<_MatchPlayer> players;
  const _StatsTable(
      {required this.label, required this.color, required this.players});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11))),
            child: Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTextStyles.label.copyWith(
                      color: color, fontSize: 12, letterSpacing: 1.0)),
            ])),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const SizedBox(width: 180),
              ...['K', 'D', 'A', 'ADR', 'HLTV', 'ELO±'].map((h) => SizedBox(
                  width: 65,
                  child: Text(h,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary, letterSpacing: 0.8))))
            ])),
        ...players.map((p) => _PlayerStatRow(player: p, teamColor: color)),
      ]),
    );
  }
}

class _PlayerStatRow extends StatelessWidget {
  final _MatchPlayer player;
  final Color teamColor;
  const _PlayerStatRow({required this.player, required this.teamColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
      child: Row(children: [
        SizedBox(
            width: 180,
            child: Row(children: [
              Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: teamColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                      image: player.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(player.avatarUrl!),
                              fit: BoxFit.cover)
                          : null),
                  child: player.avatarUrl == null
                      ? Center(
                          child: Text(player.username[0].toUpperCase(),
                              style: AppTextStyles.caption.copyWith(
                                  color: teamColor,
                                  fontWeight: FontWeight.w700)))
                      : null),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(player.username,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis)),
            ])),
        _s('${player.kills}'),
        _s('${player.deaths}'),
        _s('${player.assists}'),
        _s(player.adr.toStringAsFixed(1)),
        _s(player.hltvRating.toStringAsFixed(2), c: _rc(player.hltvRating)),
        _s(player.eloChange != 0 ? Formatters.eloChange(player.eloChange) : '-',
            c: player.eloChange > 0
                ? AppColors.success
                : player.eloChange < 0
                    ? AppColors.danger
                    : AppColors.textTertiary),
      ]),
    );
  }

  Widget _s(String v, {Color? c}) => SizedBox(
      width: 65,
      child: Text(v,
          textAlign: TextAlign.center,
          style: AppTextStyles.mono
              .copyWith(fontSize: 12, color: c ?? AppColors.textSecondary)));
  Color _rc(double r) => r >= 1.3
      ? AppColors.success
      : r >= 1.0
          ? AppColors.textSecondary
          : r >= 0.8
              ? AppColors.warning
              : AppColors.danger;
}

class _MatchResultCard extends StatelessWidget {
  final MatchModel match;
  const _MatchResultCard({required this.match});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        const Icon(Icons.emoji_events_rounded,
            color: AppColors.warning, size: 36),
        const SizedBox(height: 12),
        Text(
            match.winner != null
                ? '${match.winner == "team_a" ? "Team A" : "Team B"} Wins!'
                : 'Match Finished',
            style: AppTextStyles.h3),
        const SizedBox(height: 8),
        Text(match.score,
            style: AppTextStyles.monoLarge.copyWith(fontSize: 28)),
        if (match.entryFee > 0) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Pot: ${Formatters.currency(match.totalPot)}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(width: 20),
            Text('Rake: ${Formatters.currency(match.rakeAmount)}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textTertiary)),
          ])
        ],
      ]),
    );
  }
}
