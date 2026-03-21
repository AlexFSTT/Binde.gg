import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/lobby_model.dart';
import '../../../data/repositories/lobby_repository.dart';
import '../../../shared/widgets/status_badge.dart';
import 'widgets/create_lobby_dialog.dart';
import '../../../shared/widgets/bounce_dialog.dart';
import '../../../shared/widgets/glass_card.dart';

class LobbyBrowserScreen extends StatefulWidget {
  const LobbyBrowserScreen({super.key});

  @override
  State<LobbyBrowserScreen> createState() => _LobbyBrowserScreenState();
}

class _LobbyBrowserScreenState extends State<LobbyBrowserScreen> {
  final _lobbyRepo = LobbyRepository();

  List<LobbyModel> _lobbies = [];
  List<LobbyModel> _activeLobbies = [];
  List<LobbyModel> _pastLobbies = [];
  bool _isLoading = true;
  bool _showPast = false;

  // Filters
  String? _modeFilter;
  String? _regionFilter;

  static const _modes = ['All', '1v1', '2v2', '5v5'];
  static const _regions = ['All', 'EU', 'NA', 'SA', 'AS', 'OC'];

  String get _userId => SupabaseConfig.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadLobbies(),
      _loadMyLobbies(),
    ]);
  }

  Future<void> _loadMyLobbies() async {
    final activeResult = await _lobbyRepo.getMyActiveLobbies(_userId);
    final pastResult = await _lobbyRepo.getMyPastLobbies(_userId);

    if (!mounted) return;

    setState(() {
      if (activeResult.isSuccess) _activeLobbies = activeResult.data ?? [];
      if (pastResult.isSuccess) _pastLobbies = pastResult.data ?? [];
    });
  }

  Future<void> _loadLobbies() async {
    setState(() => _isLoading = true);

    final result = await _lobbyRepo.getOpenLobbies(
      mode: _modeFilter,
      region: _regionFilter,
    );

    if (!mounted) return;

    result.when(
      success: (lobbies) => setState(() {
        _lobbies = lobbies;
        _isLoading = false;
      }),
      failure: (_, __) => setState(() => _isLoading = false),
    );
  }

  void _setMode(String mode) {
    _modeFilter = mode == 'All' ? null : mode;
    _loadLobbies();
  }

  void _setRegion(String region) {
    _regionFilter = region == 'All' ? null : region;
    _loadLobbies();
  }

  void _openCreateDialog() async {
    // Block if already in active lobby
    if (_activeLobbies.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are already in an active lobby ("${_activeLobbies.first.name}"). Leave it first.'),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Go to lobby',
            textColor: AppColors.bgBase,
            onPressed: () => context.go('/lobby/${_activeLobbies.first.id}'),
          ),
        ),
      );
      return;
    }

    final created = await showBounceDialog<LobbyModel>(
      context: context,
      builder: (_) => const CreateLobbyDialog(),
    );
    if (created != null && mounted) {
      _loadMyLobbies(); // Refresh active lobbies
      context.go('/lobby/${created.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      child: Padding(
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
                      Text('Lobbies', style: AppTextStyles.h2),
                      const SizedBox(height: 4),
                      Text(
                        'Browse open lobbies or create your own',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create Lobby'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Your Active Lobbies ─────────────────
            if (_activeLobbies.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.play_circle_rounded, size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text('Your Active Lobbies',
                            style: AppTextStyles.label.copyWith(
                                color: AppColors.accent, fontSize: 13)),
                        const Spacer(),
                        Text('${_activeLobbies.length} active',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._activeLobbies.map((lobby) => _ActiveLobbyCard(
                          lobby: lobby,
                          onTap: () => context.go('/lobby/${lobby.id}'),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Past Lobbies toggle ─────────────────
            if (_pastLobbies.isNotEmpty) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _showPast = !_showPast),
                  child: Row(
                    children: [
                      Icon(
                        _showPast ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Past Lobbies (${_pastLobbies.length})',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showPast) ...[
                const SizedBox(height: 8),
                ..._pastLobbies.map((lobby) => _PastLobbyRow(
                      lobby: lobby,
                      onTap: () => context.go('/lobby/${lobby.id}'),
                    )),
              ],
              const SizedBox(height: 16),
            ],

            // ── Filters ────────────────────────────
            Row(
              children: [
                // Mode filter
                Text('Mode:',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(width: 8),
                ..._modes.map((m) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Chip(
                        label: m,
                        isActive: (m == 'All' && _modeFilter == null) ||
                            m == _modeFilter,
                        onTap: () => _setMode(m),
                      ),
                    )),

                const SizedBox(width: 24),

                // Region filter
                Text('Region:',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(width: 8),
                ..._regions.map((r) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Chip(
                        label: r,
                        isActive: (r == 'All' && _regionFilter == null) ||
                            r == _regionFilter,
                        onTap: () => _setRegion(r),
                      ),
                    )),

                const Spacer(),

                // Refresh
                IconButton(
                  onPressed: _loadLobbies,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppColors.textTertiary,
                  tooltip: 'Refresh',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Table Header ───────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  SizedBox(width: 60, child: _colHeader('MODE')),
                  Expanded(flex: 3, child: _colHeader('LOBBY NAME')),
                  SizedBox(width: 70, child: _colHeader('REGION')),
                  SizedBox(width: 90, child: _colHeader('ELO RANGE')),
                  SizedBox(width: 80, child: _colHeader('PLAYERS')),
                  SizedBox(width: 80, child: _colHeader('FEE')),
                  SizedBox(width: 70, child: _colHeader('STATUS')),
                ],
              ),
            ),

            // ── Lobby List ─────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _lobbies.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.groups_outlined,
                                    size: 48,
                                    color: AppColors.textTertiary
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text('No open lobbies found',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text('Try different filters or create your own',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textTertiary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _lobbies.length,
                            itemBuilder: (context, i) => _LobbyRow(
                              lobby: _lobbies[i],
                              onTap: () =>
                                  context.go('/lobby/${_lobbies[i].id}'),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _colHeader(String text) => Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textTertiary,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );

class _LobbyRow extends StatefulWidget {
  final LobbyModel lobby;
  final VoidCallback onTap;
  const _LobbyRow({required this.lobby, required this.onTap});

  @override
  State<_LobbyRow> createState() => _LobbyRowState();
}

class _LobbyRowState extends State<_LobbyRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.lobby;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _hovered ? AppColors.bgSurfaceHover : AppColors.bgSurface,
          child: Row(
            children: [
              // Mode
              SizedBox(
                width: 60,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceActive,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(l.mode,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.mono
                          .copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),

              // Name
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    if (l.isPrivate) ...[
                      const Icon(Icons.lock_rounded,
                          size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(l.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),

              // Region
              SizedBox(
                  width: 70,
                  child: Text(l.region,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary))),

              // ELO range
              SizedBox(
                width: 90,
                child: Text('${l.minElo} - ${l.maxElo}',
                    style: AppTextStyles.mono
                        .copyWith(fontSize: 11, color: AppColors.textTertiary)),
              ),

              // Players
              SizedBox(
                width: 80,
                child: Row(
                  children: [
                    Text('${l.currentPlayers}/${l.maxPlayers}',
                        style: AppTextStyles.mono.copyWith(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    // Progress bar
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: l.maxPlayers > 0
                              ? l.currentPlayers / l.maxPlayers
                              : 0,
                          minHeight: 4,
                          backgroundColor: AppColors.bgSurfaceActive,
                          color:
                              l.isFull ? AppColors.warning : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Fee
              SizedBox(
                width: 80,
                child: Text(
                  l.entryFee > 0 ? Formatters.currency(l.entryFee) : 'Free',
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        l.entryFee > 0 ? AppColors.primary : AppColors.success,
                  ),
                ),
              ),

              // Status
              SizedBox(
                width: 70,
                child: l.isFull ? StatusBadge.full() : StatusBadge.open(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.isActive, required this.onTap});

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : _hovered
                    ? AppColors.bgSurfaceHover
                    : AppColors.bgSurfaceActive,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Text(widget.label,
              style: AppTextStyles.caption.copyWith(
                color: widget.isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
      ),
    );
  }
}

/// Highlighted card for an active lobby the user is in.
class _ActiveLobbyCard extends StatefulWidget {
  final LobbyModel lobby;
  final VoidCallback onTap;
  const _ActiveLobbyCard({required this.lobby, required this.onTap});

  @override
  State<_ActiveLobbyCard> createState() => _ActiveLobbyCardState();
}

class _ActiveLobbyCardState extends State<_ActiveLobbyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.lobby;
    final isLive = l.status == 'in_match';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.accent.withValues(alpha: 0.10)
                : AppColors.bgSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLive ? AppColors.danger : AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceActive,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(l.mode,
                    style: AppTextStyles.mono.copyWith(
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${l.region} · ${l.currentPlayers}/${l.maxPlayers} players',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              if (isLive) StatusBadge.live() else const StatusBadge(label: 'Open', color: AppColors.success),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _hovered ? AppColors.accent : AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact row for a past lobby.
class _PastLobbyRow extends StatefulWidget {
  final LobbyModel lobby;
  final VoidCallback onTap;
  const _PastLobbyRow({required this.lobby, required this.onTap});

  @override
  State<_PastLobbyRow> createState() => _PastLobbyRowState();
}

class _PastLobbyRowState extends State<_PastLobbyRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.lobby;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bgSurfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceActive,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l.mode,
                    style: AppTextStyles.mono.copyWith(
                        fontSize: 10, color: AppColors.textTertiary)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.name,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                l.status == 'finished' ? 'Finished' : 'Cancelled',
                style: AppTextStyles.caption.copyWith(
                  color: l.status == 'finished'
                      ? AppColors.textTertiary
                      : AppColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.timeAgo(l.createdAt),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
