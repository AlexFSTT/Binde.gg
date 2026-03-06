import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/lobby_model.dart';
import '../../../data/repositories/lobby_repository.dart';
import '../../../shared/widgets/status_badge.dart';
import 'widgets/create_lobby_dialog.dart';

class LobbyBrowserScreen extends StatefulWidget {
  const LobbyBrowserScreen({super.key});

  @override
  State<LobbyBrowserScreen> createState() => _LobbyBrowserScreenState();
}

class _LobbyBrowserScreenState extends State<LobbyBrowserScreen> {
  final _lobbyRepo = LobbyRepository();

  List<LobbyModel> _lobbies = [];
  bool _isLoading = true;

  // Filters
  String? _modeFilter;
  String? _regionFilter;

  static const _modes = ['All', '1v1', '2v2', '5v5'];
  static const _regions = ['All', 'EU', 'NA', 'SA', 'AS', 'OC'];

  @override
  void initState() {
    super.initState();
    _loadLobbies();
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
    final created = await showDialog<LobbyModel>(
      context: context,
      builder: (_) => const CreateLobbyDialog(),
    );
    if (created != null && mounted) {
      context.go('/lobby/${created.id}');
    }
  }

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
