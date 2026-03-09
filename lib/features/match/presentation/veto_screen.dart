import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/logger.dart';

/// Map veto screen — alternating bans between Team A and Team B.
/// This is rendered as a child of MatchScreen.
/// It does NOT navigate — the parent MatchScreen handles transitions
/// when the match status changes from 'veto' to 'ready_check'.
class MapVetoScreen extends StatefulWidget {
  final String matchId;
  /// Called when veto is detected as complete (parent should refresh)
  final VoidCallback? onVetoComplete;

  const MapVetoScreen({super.key, required this.matchId, this.onVetoComplete});

  @override
  State<MapVetoScreen> createState() => _MapVetoScreenState();
}

class _MapVetoScreenState extends State<MapVetoScreen> {
  final _client = SupabaseConfig.client;

  String? _myTeam;
  String? _currentTurnTeam;
  String? _selectedMap;

  List<_MapInfo> _maps = [];
  final Set<String> _bannedMaps = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  DateTime? _turnExpiry;
  Timer? _timer;
  int _secondsLeft = 30;

  String get _userId => SupabaseConfig.auth.currentUser!.id;
  bool get _isMyTurn => _currentTurnTeam == _myTeam;

  @override
  void initState() {
    super.initState();
    Log.d('VetoScreen initState for match: ${widget.matchId}');
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // 1. Get my team
      final playerData = await _client
          .from('match_players')
          .select('team')
          .eq('match_id', widget.matchId)
          .eq('player_id', _userId)
          .single();
      _myTeam = playerData['team'] as String;

      // 2. Get match state
      final matchData = await _client
          .from('matches')
          .select('status, veto_turn_team, veto_turn_expires_at, map')
          .eq('id', widget.matchId)
          .single();

      final status = matchData['status'] as String;
      _currentTurnTeam = matchData['veto_turn_team'] as String?;
      _selectedMap = matchData['map'] as String?;
      if (matchData['veto_turn_expires_at'] != null) {
        _turnExpiry = DateTime.parse(matchData['veto_turn_expires_at']);
      }

      Log.d('Veto state: status=$status, turn=$_currentTurnTeam, map=$_selectedMap');

      // 3. If not in veto anymore, tell parent
      if (status != 'veto') {
        Log.d('Veto already complete, notifying parent');
        widget.onVetoComplete?.call();
        return;
      }

      // 4. Get active map pool
      final mapsData = await _client
          .from('map_pool')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      _maps = mapsData
          .map((m) => _MapInfo(
                name: m['name'] as String,
                displayName: m['display_name'] as String,
                imageUrl: m['image_url'] as String?,
              ))
          .toList();

      // 5. Get existing vetoes
      final vetoData = await _client
          .from('map_vetoes')
          .select('map_name, team')
          .eq('match_id', widget.matchId)
          .order('veto_order');

      for (final v in vetoData) {
        _bannedMaps.add(v['map_name'] as String);
      }

      setState(() => _isLoading = false);
      _startTimer();
    } catch (e) {
      Log.e('Veto loadData error', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_turnExpiry != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final remaining = _turnExpiry!.difference(DateTime.now()).inSeconds;
        setState(() => _secondsLeft = remaining.clamp(0, 30));
        if (remaining <= 0) {
          _timer?.cancel();
        }
      });
    }
  }

  /// Called from parent when realtime updates the veto state
  void updateVetoState({
    String? turnTeam,
    String? selectedMap,
    DateTime? expiresAt,
    Set<String>? newBans,
  }) {
    if (!mounted) return;
    setState(() {
      if (turnTeam != null) _currentTurnTeam = turnTeam;
      if (selectedMap != null) _selectedMap = selectedMap;
      if (expiresAt != null) {
        _turnExpiry = expiresAt;
        _startTimer();
      }
      if (newBans != null) _bannedMaps.addAll(newBans);
    });
  }

  Future<void> _banMap(String mapName) async {
    if (!_isMyTurn || _isSubmitting || _bannedMaps.contains(mapName)) return;

    setState(() => _isSubmitting = true);
    Log.d('Banning map: $mapName');

    try {
      final result = await _client.rpc('fn_process_veto', params: {
        'p_match_id': widget.matchId,
        'p_player_id': _userId,
        'p_map_name': mapName,
        'p_action': 'ban',
      });

      if (!mounted) return;

      final data = result as Map<String, dynamic>;

      if (data['success'] == true) {
        Log.d('Veto success: complete=${data['veto_complete']}, remaining=${data['remaining_maps']}');
        setState(() {
          _bannedMaps.add(mapName);
          _isSubmitting = false;
        });

        if (data['veto_complete'] == true) {
          setState(() => _selectedMap = data['selected_map'] as String?);
          // Parent will detect status change via realtime and re-render
        }
      } else {
        Log.e('Veto failed: ${data['error']}');
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Veto failed'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Veto exception', error: e);
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // Veto complete — show selected map briefly
    if (_selectedMap != null) {
      return _VetoCompleteView(selectedMap: _selectedMap!, maps: _maps);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text('MAP VETO', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                _isMyTurn
                    ? 'Your turn — ban a map!'
                    : 'Waiting for opponent to ban...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _isMyTurn ? AppColors.primary : AppColors.textTertiary,
                  fontWeight: _isMyTurn ? FontWeight.w600 : FontWeight.w400,
                ),
              ),

              const SizedBox(height: 8),

              // Turn indicator + timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TeamBadge(
                    label: 'Team A',
                    color: const Color(0xFF3498DB),
                    isActive: _currentTurnTeam == 'team_a',
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _secondsLeft <= 5
                          ? AppColors.dangerMuted
                          : AppColors.bgSurfaceActive,
                      border: Border.all(
                        color: _secondsLeft <= 5
                            ? AppColors.danger
                            : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$_secondsLeft',
                        style: AppTextStyles.monoLarge.copyWith(
                          color: _secondsLeft <= 5
                              ? AppColors.danger
                              : AppColors.textPrimary,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _TeamBadge(
                    label: 'Team B',
                    color: const Color(0xFFE74C3C),
                    isActive: _currentTurnTeam == 'team_b',
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Map Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 16 / 10,
                  ),
                  itemCount: _maps.length,
                  itemBuilder: (context, i) {
                    final map = _maps[i];
                    final isBanned = _bannedMaps.contains(map.name);
                    final canBan = _isMyTurn && !isBanned && !_isSubmitting;

                    return _MapCard(
                      map: map,
                      isBanned: isBanned,
                      canBan: canBan,
                      onBan: () => _banMap(map.name),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapInfo {
  final String name, displayName;
  final String? imageUrl;
  const _MapInfo({required this.name, required this.displayName, this.imageUrl});
}

class _MapCard extends StatefulWidget {
  final _MapInfo map;
  final bool isBanned, canBan;
  final VoidCallback onBan;

  const _MapCard({
    required this.map,
    required this.isBanned,
    required this.canBan,
    required this.onBan,
  });

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.canBan ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.canBan ? widget.onBan : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isBanned
                ? AppColors.dangerMuted
                : _hovered && widget.canBan
                    ? AppColors.danger.withValues(alpha: 0.08)
                    : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isBanned
                  ? AppColors.danger.withValues(alpha: 0.3)
                  : _hovered && widget.canBan
                      ? AppColors.danger.withValues(alpha: 0.4)
                      : AppColors.border,
              width: _hovered && widget.canBan ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_rounded,
                      size: 28,
                      color: widget.isBanned
                          ? AppColors.danger.withValues(alpha: 0.4)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.map.displayName,
                      style: AppTextStyles.label.copyWith(
                        color: widget.isBanned
                            ? AppColors.danger.withValues(alpha: 0.5)
                            : AppColors.textPrimary,
                        fontSize: 15,
                        decoration: widget.isBanned ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.map.name,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isBanned)
                Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.block_rounded,
                      size: 48,
                      color: AppColors.danger.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              if (_hovered && widget.canBan)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('BAN',
                          style: AppTextStyles.caption
                              .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
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

class _TeamBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;

  const _TeamBadge({required this.label, required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.12) : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? color : AppColors.border,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: isActive ? color : AppColors.textTertiary,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _VetoCompleteView extends StatelessWidget {
  final String selectedMap;
  final List<_MapInfo> maps;

  const _VetoCompleteView({required this.selectedMap, required this.maps});

  @override
  Widget build(BuildContext context) {
    final mapInfo = maps.where((m) => m.name == selectedMap).firstOrNull;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
          const SizedBox(height: 20),
          Text('MAP SELECTED',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary, letterSpacing: 2, fontSize: 14)),
          const SizedBox(height: 12),
          Text(mapInfo?.displayName ?? selectedMap,
              style: AppTextStyles.h1.copyWith(fontSize: 48)),
          const SizedBox(height: 8),
          Text(selectedMap,
              style: AppTextStyles.mono.copyWith(color: AppColors.textTertiary, fontSize: 16)),
          const SizedBox(height: 32),
          Text('Preparing server...',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 16),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
