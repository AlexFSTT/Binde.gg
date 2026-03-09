import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/lobby_model.dart';
import '../../../data/repositories/lobby_repository.dart';
import '../../../services/realtime/realtime_service.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/elo_badge.dart';
import '../../../shared/widgets/app_button.dart';

class LobbyDetailScreen extends StatefulWidget {
  final String lobbyId;
  const LobbyDetailScreen({super.key, required this.lobbyId});

  @override
  State<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends State<LobbyDetailScreen> {
  final _lobbyRepo = LobbyRepository();
  final _realtime = RealtimeService();
  final _client = SupabaseConfig.client;

  LobbyModel? _lobby;
  List<_PlayerEntry> _players = [];
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;

  String get _userId => SupabaseConfig.auth.currentUser!.id;
  bool get _isInLobby => _players.any((p) => p.id == _userId);
  bool get _isCreator => _lobby?.createdBy == _userId;
  _PlayerEntry? get _myEntry =>
      _players.where((p) => p.id == _userId).firstOrNull;

  bool get _allReady =>
      _players.isNotEmpty &&
      _players.length == (_lobby?.maxPlayers ?? 0) &&
      _players.every((p) => p.isReady);

  @override
  void initState() {
    super.initState();
    _loadLobby();
  }

  @override
  void dispose() {
    _realtime.unsubscribe('lobby:${widget.lobbyId}');
    super.dispose();
  }

  Future<void> _loadLobby() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final lobbyResult = await _lobbyRepo.getLobby(widget.lobbyId);
    if (!mounted) return;

    if (lobbyResult.isFailure) {
      setState(() {
        _isLoading = false;
        _error = lobbyResult.error;
      });
      return;
    }

    await _loadPlayers();

    setState(() {
      _lobby = lobbyResult.data;
      _isLoading = false;
    });

    _subscribeRealtime();
  }

  Future<void> _loadPlayers() async {
    try {
      final data = await _client
          .from('lobby_players')
          .select(
              '*, profile:profiles(id, username, elo_rating, steam_avatar_url)')
          .eq('lobby_id', widget.lobbyId);

      if (!mounted) return;

      setState(() {
        _players = data.map((row) {
          final profile = row['profile'] as Map<String, dynamic>;
          return _PlayerEntry(
            id: profile['id'] as String,
            username: profile['username'] as String,
            elo: profile['elo_rating'] as int? ?? 1000,
            avatarUrl: profile['steam_avatar_url'] as String?,
            team: row['team'] as String?,
            isReady: row['is_ready'] as bool? ?? false,
            isCaptain: row['is_captain'] as bool? ?? false,
          );
        }).toList();
      });
    } catch (_) {}
  }

  void _subscribeRealtime() {
    _realtime.subscribeLobby(
      lobbyId: widget.lobbyId,
      onPlayerJoin: (_) => _loadPlayers(),
      onPlayerLeave: (_) => _loadPlayers(),
      onPlayerUpdate: (_) => _loadPlayers(),
      onLobbyUpdate: (data) async {
        if (!mounted) return;
        final updatedLobby = LobbyModel.fromJson(data);
        setState(() => _lobby = updatedLobby);

        // If lobby moved to in_match, find the match and redirect
        if (updatedLobby.status == 'in_match') {
          try {
            final matchData = await _client
                .from('matches')
                .select('id')
                .eq('lobby_id', widget.lobbyId)
                .order('created_at', ascending: false)
                .limit(1)
                .single();

            if (mounted) {
              context.go('/match/${matchData['id']}');
            }
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _joinLobby() async {
    final result = await _lobbyRepo.joinLobby(widget.lobbyId, _userId);
    if (mounted && result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.error ?? 'Failed to join'),
            backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _leaveLobby() async {
    await _lobbyRepo.leaveLobby(widget.lobbyId, _userId);
    if (mounted && _isCreator) {
      context.go('/lobbies');
    }
  }

  Future<void> _toggleReady() async {
    final current = _myEntry?.isReady ?? false;
    await _lobbyRepo.setReady(widget.lobbyId, _userId, !current);
  }

  /// START MATCH — calls fn_start_match database function
  Future<void> _startMatch() async {
    setState(() => _isStarting = true);

    try {
      final result = await _client.rpc('fn_start_match', params: {
        'p_lobby_id': widget.lobbyId,
        'p_started_by': _userId,
      });

      if (!mounted) return;

      final data = result as Map<String, dynamic>;

      if (data['success'] == true) {
        final matchId = data['match_id'] as String;
        context.go('/match/$matchId');
      } else {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(data['message'] ?? data['error'] ?? 'Failed to start'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
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

    if (_error != null || _lobby == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text('Lobby not found',
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () => context.go('/lobbies'),
                  child: const Text('Back to Lobbies')),
            ],
          ),
        ),
      );
    }

    final lobby = _lobby!;
    final teamA = _players.where((p) => p.team == 'team_a').toList();
    final teamB = _players.where((p) => p.team == 'team_b').toList();
    final unassigned = _players.where((p) => p.team == null).toList();
    final slotsPerTeam = lobby.maxPlayers ~/ 2;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back + Header ──────────────────────
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/lobbies'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(lobby.name, style: AppTextStyles.h2),
                          const SizedBox(width: 12),
                          if (lobby.isPrivate)
                            const Icon(Icons.lock_rounded,
                                size: 16, color: AppColors.textTertiary),
                          const SizedBox(width: 8),
                          lobby.isFull
                              ? StatusBadge.full()
                              : StatusBadge.open(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lobby.mode} · ${lobby.region} · ELO ${lobby.minElo}-${lobby.maxElo} · ${lobby.entryFee > 0 ? Formatters.currency(lobby.entryFee) : "Free"}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),

                // ── Action Buttons ─────────────────
                if (_isCreator && _allReady) ...[
                  // START MATCH button — only for creator when all ready
                  AppButton(
                    label: 'START MATCH',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _isStarting ? null : _startMatch,
                    isLoading: _isStarting,
                  ),
                  const SizedBox(width: 10),
                ] else if (_isInLobby) ...[
                  AppButton(
                    label: _myEntry?.isReady == true ? 'UNREADY' : 'READY UP',
                    variant: _myEntry?.isReady == true
                        ? AppButtonVariant.secondary
                        : AppButtonVariant.primary,
                    icon: _myEntry?.isReady == true
                        ? Icons.close_rounded
                        : Icons.check_rounded,
                    onPressed: _toggleReady,
                  ),
                  const SizedBox(width: 10),
                ],
                if (_isInLobby) ...[
                  AppButton(
                    label: 'Leave',
                    variant: AppButtonVariant.danger,
                    icon: Icons.logout_rounded,
                    onPressed: _leaveLobby,
                  ),
                ] else if (lobby.isOpen && !lobby.isFull) ...[
                  AppButton(
                    label: 'Join Lobby',
                    icon: Icons.login_rounded,
                    onPressed: _joinLobby,
                  ),
                ],
              ],
            ),

            // ── "All Ready" banner ─────────────────
            if (_allReady && !_isCreator && _isInLobby) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.successMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'All players ready! Waiting for lobby creator to start the match...',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Teams ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TeamPanel(
                    teamLabel: 'TEAM A',
                    color: const Color(0xFF3498DB),
                    players: teamA,
                    maxSlots: slotsPerTeam,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurfaceActive,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Text('VS',
                              style: AppTextStyles.label.copyWith(
                                  color: AppColors.textTertiary, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _TeamPanel(
                    teamLabel: 'TEAM B',
                    color: const Color(0xFFE74C3C),
                    players: teamB,
                    maxSlots: slotsPerTeam,
                  ),
                ),
              ],
            ),

            if (unassigned.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UNASSIGNED',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary, letterSpacing: 1.0)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: unassigned
                          .map((p) => _PlayerChip(player: p))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),
            _LobbyInfoBar(lobby: lobby, playerCount: _players.length),
          ],
        ),
      ),
    );
  }
}

// ── Supporting Widgets (same as before) ──────────────────────

class _PlayerEntry {
  final String id, username;
  final int elo;
  final String? avatarUrl, team;
  final bool isReady, isCaptain;

  const _PlayerEntry({
    required this.id,
    required this.username,
    required this.elo,
    this.avatarUrl,
    this.team,
    this.isReady = false,
    this.isCaptain = false,
  });
}

class _TeamPanel extends StatelessWidget {
  final String teamLabel;
  final Color color;
  final List<_PlayerEntry> players;
  final int maxSlots;

  const _TeamPanel(
      {required this.teamLabel,
      required this.color,
      required this.players,
      required this.maxSlots});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Text(teamLabel,
                    style: AppTextStyles.label.copyWith(
                        color: color, letterSpacing: 1.0, fontSize: 13)),
                const Spacer(),
                Text('${players.length}/$maxSlots',
                    style: AppTextStyles.mono
                        .copyWith(fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          ...List.generate(maxSlots, (i) {
            if (i < players.length) {
              return _PlayerRow(player: players[i], teamColor: color);
            }
            return _EmptySlot(index: i + 1);
          }),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final _PlayerEntry player;
  final Color teamColor;
  const _PlayerRow({required this.player, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: player.isReady
                  ? AppColors.success
                  : AppColors.textTertiary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              image: player.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(player.avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: player.avatarUrl == null
                ? Center(
                    child: Text(player.username[0].toUpperCase(),
                        style: AppTextStyles.label
                            .copyWith(color: teamColor, fontSize: 13)))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(children: [
              Text(player.username,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              if (player.isCaptain) ...[
                const SizedBox(width: 6),
                const Icon(Icons.star_rounded,
                    size: 14, color: AppColors.warning),
              ],
            ]),
          ),
          EloBadge(elo: player.elo),
          const SizedBox(width: 10),
          Text(
            player.isReady ? 'READY' : 'NOT READY',
            style: AppTextStyles.caption.copyWith(
              color:
                  player.isReady ? AppColors.success : AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final int index;
  const _EmptySlot({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.bgSurfaceActive)),
        const SizedBox(width: 12),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceActive,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: 10),
        Text('Waiting for player...',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textTertiary)),
      ]),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final _PlayerEntry player;
  const _PlayerChip({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceActive,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(player.username,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(width: 6),
        EloBadge(elo: player.elo),
      ]),
    );
  }
}

class _LobbyInfoBar extends StatelessWidget {
  final LobbyModel lobby;
  final int playerCount;
  const _LobbyInfoBar({required this.lobby, required this.playerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoItem(label: 'Mode', value: lobby.mode),
          _InfoItem(label: 'Region', value: lobby.region),
          _InfoItem(
              label: 'Entry Fee',
              value: lobby.entryFee > 0
                  ? Formatters.currency(lobby.entryFee)
                  : 'Free'),
          _InfoItem(
              label: 'Players', value: '$playerCount/${lobby.maxPlayers}'),
          _InfoItem(
              label: 'ELO Range', value: '${lobby.minElo} - ${lobby.maxElo}'),
          _InfoItem(
              label: 'Created', value: Formatters.timeAgo(lobby.createdAt)),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label, value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
      const SizedBox(height: 4),
      Text(value,
          style: AppTextStyles.mono
              .copyWith(fontSize: 13, color: AppColors.textPrimary)),
    ]);
  }
}
