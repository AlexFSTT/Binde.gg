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
  String? _error;

  String get _userId => SupabaseConfig.auth.currentUser!.id;
  bool get _isInLobby => _players.any((p) => p.id == _userId);
  bool get _isCreator => _lobby?.createdBy == _userId;
  _PlayerEntry? get _myEntry => _players.where((p) => p.id == _userId).firstOrNull;

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

    // Fetch lobby
    final lobbyResult = await _lobbyRepo.getLobby(widget.lobbyId);
    if (!mounted) return;

    if (lobbyResult.isFailure) {
      setState(() {
        _isLoading = false;
        _error = lobbyResult.error;
      });
      return;
    }

    // Fetch players with profile data
    await _loadPlayers();

    setState(() {
      _lobby = lobbyResult.data;
      _isLoading = false;
    });

    // Subscribe to real-time updates
    _subscribeRealtime();
  }

  Future<void> _loadPlayers() async {
    try {
      final data = await _client
          .from('lobby_players')
          .select('*, profile:profiles(id, username, elo_rating, steam_avatar_url)')
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
      onLobbyUpdate: (data) {
        if (!mounted) return;
        setState(() {
          _lobby = LobbyModel.fromJson(data);
        });
      },
    );
  }

  Future<void> _joinLobby() async {
    final result = await _lobbyRepo.joinLobby(widget.lobbyId, _userId);
    if (mounted && result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to join'), backgroundColor: AppColors.danger),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null || _lobby == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text('Lobby not found', style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => context.go('/lobbies'), child: const Text('Back to Lobbies')),
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
                            const Icon(Icons.lock_rounded, size: 16, color: AppColors.textTertiary),
                          const SizedBox(width: 8),
                          lobby.isFull ? StatusBadge.full() : StatusBadge.open(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lobby.mode} · ${lobby.region} · ELO ${lobby.minElo}-${lobby.maxElo} · ${lobby.entryFee > 0 ? Formatters.currency(lobby.entryFee) : "Free"}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                if (_isInLobby) ...[
                  AppButton(
                    label: _myEntry?.isReady == true ? 'UNREADY' : 'READY UP',
                    variant: _myEntry?.isReady == true ? AppButtonVariant.secondary : AppButtonVariant.primary,
                    icon: _myEntry?.isReady == true ? Icons.close_rounded : Icons.check_rounded,
                    onPressed: _toggleReady,
                  ),
                  const SizedBox(width: 10),
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

            const SizedBox(height: 28),

            // ── Teams ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team A
                Expanded(
                  child: _TeamPanel(
                    teamLabel: 'TEAM A',
                    color: const Color(0xFF3498DB),
                    players: teamA,
                    maxSlots: slotsPerTeam,
                  ),
                ),

                // VS divider
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

                // Team B
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

            // Unassigned players
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
                      children: unassigned.map((p) => _PlayerChip(player: p)).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Lobby Info ─────────────────────────
            _LobbyInfoBar(lobby: lobby, playerCount: _players.length),
          ],
        ),
      ),
    );
  }
}

class _PlayerEntry {
  final String id;
  final String username;
  final int elo;
  final String? avatarUrl;
  final String? team;
  final bool isReady;
  final bool isCaptain;

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

  const _TeamPanel({
    required this.teamLabel,
    required this.color,
    required this.players,
    required this.maxSlots,
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
        children: [
          // Team header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Text(teamLabel,
                    style: AppTextStyles.label.copyWith(
                        color: color, letterSpacing: 1.0, fontSize: 13)),
                const Spacer(),
                Text('${players.length}/$maxSlots',
                    style: AppTextStyles.mono.copyWith(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),

          // Player slots
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
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          // Ready indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: player.isReady ? AppColors.success : AppColors.textTertiary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              image: player.avatarUrl != null
                  ? DecorationImage(image: NetworkImage(player.avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: player.avatarUrl == null
                ? Center(
                    child: Text(player.username[0].toUpperCase(),
                        style: AppTextStyles.label.copyWith(color: teamColor, fontSize: 13)))
                : null,
          ),
          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Row(
              children: [
                Text(player.username,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                if (player.isCaptain) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                ],
              ],
            ),
          ),

          // ELO
          EloBadge(elo: player.elo),

          const SizedBox(width: 10),

          // Ready text
          Text(
            player.isReady ? 'READY' : 'NOT READY',
            style: AppTextStyles.caption.copyWith(
              color: player.isReady ? AppColors.success : AppColors.textTertiary,
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
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgSurfaceActive,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceActive,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, style: BorderStyle.solid),
            ),
          ),
          const SizedBox(width: 10),
          Text('Waiting for player...',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
        ],
      ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(player.username, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          EloBadge(elo: player.elo),
        ],
      ),
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
          _InfoItem(label: 'Entry Fee', value: lobby.entryFee > 0 ? Formatters.currency(lobby.entryFee) : 'Free'),
          _InfoItem(label: 'Players', value: '$playerCount/${lobby.maxPlayers}'),
          _InfoItem(label: 'ELO Range', value: '${lobby.minElo} - ${lobby.maxElo}'),
          _InfoItem(label: 'Created', value: Formatters.timeAgo(lobby.createdAt)),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.mono.copyWith(fontSize: 13, color: AppColors.textPrimary)),
      ],
    );
  }
}
