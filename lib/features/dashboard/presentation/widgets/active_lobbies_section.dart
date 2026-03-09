import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../data/models/lobby_model.dart';

/// Active/open lobbies section on dashboard.
/// Shows latest 5 open lobbies.
class ActiveLobbiesSection extends StatefulWidget {
  final String userId;
  const ActiveLobbiesSection({super.key, required this.userId});

  @override
  State<ActiveLobbiesSection> createState() => _ActiveLobbiesSectionState();
}

class _ActiveLobbiesSectionState extends State<ActiveLobbiesSection> {
  List<LobbyModel>? _lobbies;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLobbies();
  }

  Future<void> _loadLobbies() async {
    try {
      final client = SupabaseConfig.client;
      final data = await client
          .from('lobbies')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(5);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _lobbies = data.map((j) => LobbyModel.fromJson(j)).toList();
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
                const Icon(Icons.groups_rounded,
                    size: 18, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(
                  'Active Lobbies',
                  style: AppTextStyles.label.copyWith(fontSize: 14),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.go(Routes.lobbies),
                    child: Text(
                      'View all',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _isLoading
                ? const _LoadingState()
                : (_lobbies == null || _lobbies!.isEmpty)
                    ? const _EmptyState()
                    : Column(
                        children: _lobbies!
                            .map((l) => _LobbyRow(lobby: l))
                            .toList(),
                      ),
          ),
        ],
      ),
    );
  }
}

class _LobbyRow extends StatefulWidget {
  final LobbyModel lobby;
  const _LobbyRow({required this.lobby});

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
        onTap: () => context.go('/lobby/${l.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bgSurfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              bottom: BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          child: Row(
            children: [
              // Mode badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceActive,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l.mode,
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + region
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${l.region} · ELO ${l.minElo}-${l.maxElo}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Players count
              Text(
                '${l.currentPlayers}/${l.maxPlayers}',
                style: AppTextStyles.mono.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 14),

              // Entry fee
              Text(
                l.entryFee > 0
                    ? Formatters.currency(l.entryFee)
                    : 'Free',
                style: AppTextStyles.mono.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: l.entryFee > 0
                      ? AppColors.primary
                      : AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.groups_outlined,
                size: 40,
                color: AppColors.textTertiary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No open lobbies',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Create one to get started',
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
