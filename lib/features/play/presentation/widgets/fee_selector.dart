import 'package:flutter/material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Preset Bcoin fees for matchmaking: Free / 10 / 25 / 50 / 100 / 250 / 500.
/// Shows the user's balance and disables presets they can't afford.
class FeeSelector extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const FeeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<FeeSelector> createState() => _FeeSelectorState();
}

class _FeeSelectorState extends State<FeeSelector> {
  static const _presets = [0, 10, 25, 50, 100, 250, 500];

  int _balance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final userId = SupabaseConfig.auth.currentUser!.id;
      final row = await SupabaseConfig.client
          .from('profiles')
          .select('bcoins')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _balance = row['bcoins'] as int? ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Balance chip
        Row(
          children: [
            Text(
              'Your balance:',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary, fontSize: 11),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.accent),
                    )
                  else
                    Text(
                      '$_balance',
                      style: AppTextStyles.mono.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  const SizedBox(width: 3),
                  Text('B',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.accent.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                          fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Preset chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _presets.map((p) {
            final isSelected = widget.selected == p;
            final insufficient = p > _balance;
            return _FeeChip(
              amount: p,
              isSelected: isSelected,
              insufficient: insufficient,
              onTap: insufficient ? null : () => widget.onChanged(p),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FeeChip extends StatefulWidget {
  final int amount;
  final bool isSelected;
  final bool insufficient;
  final VoidCallback? onTap;

  const _FeeChip({
    required this.amount,
    required this.isSelected,
    required this.insufficient,
    required this.onTap,
  });

  @override
  State<_FeeChip> createState() => _FeeChipState();
}

class _FeeChipState extends State<_FeeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;
    final disabled = widget.insufficient;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor:
          disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.accent.withValues(alpha: 0.12)
                : _hovered && !disabled
                    ? AppColors.bgSurfaceHover
                    : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : disabled
                      ? AppColors.borderSubtle
                      : AppColors.border,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.amount == 0 ? 'Free' : '${widget.amount}',
                style: AppTextStyles.mono.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: sel
                      ? AppColors.accent
                      : disabled
                          ? AppColors.textTertiary.withValues(alpha: 0.4)
                          : AppColors.textPrimary,
                ),
              ),
              if (widget.amount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  'B',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sel
                        ? AppColors.accent.withValues(alpha: 0.6)
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
