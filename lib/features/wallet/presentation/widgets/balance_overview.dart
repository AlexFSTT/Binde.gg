import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/wallet_model.dart';

/// Balance overview cards — main balance, available, locked, stats.
class BalanceOverview extends StatelessWidget {
  final WalletModel wallet;
  const BalanceOverview({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        return Column(
          children: [
            // ── Main Balance Card ──────────────────
            _MainBalanceCard(wallet: wallet),

            const SizedBox(height: 16),

            // ── Stats Row ──────────────────────────
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _MiniCard(
                  width: isWide
                      ? (constraints.maxWidth - 14 * 3) / 4
                      : (constraints.maxWidth - 14) / 2,
                  label: 'Available',
                  value: Formatters.currency(wallet.availableBalance),
                  icon: Icons.account_balance_rounded,
                  color: AppColors.success,
                ),
                _MiniCard(
                  width: isWide
                      ? (constraints.maxWidth - 14 * 3) / 4
                      : (constraints.maxWidth - 14) / 2,
                  label: 'Locked in Matches',
                  value: Formatters.currency(wallet.lockedBalance),
                  icon: Icons.lock_rounded,
                  color: AppColors.warning,
                ),
                _MiniCard(
                  width: isWide
                      ? (constraints.maxWidth - 14 * 3) / 4
                      : (constraints.maxWidth - 14) / 2,
                  label: 'Total Deposited',
                  value: Formatters.currency(wallet.totalDeposited),
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.info,
                ),
                _MiniCard(
                  width: isWide
                      ? (constraints.maxWidth - 14 * 3) / 4
                      : (constraints.maxWidth - 14) / 2,
                  label: 'Net Profit',
                  value: Formatters.currency(wallet.netProfit),
                  icon: wallet.netProfit >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: wallet.netProfit >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MainBalanceCard extends StatelessWidget {
  final WalletModel wallet;
  const _MainBalanceCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.bgSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL BALANCE',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.currency(wallet.balance),
                    style: AppTextStyles.monoLarge.copyWith(
                      fontSize: 36,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Wagered / Won summary
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SmallStat(
                    label: 'Total Wagered',
                    value: Formatters.currency(wallet.totalWagered),
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 6),
                  _SmallStat(
                    label: 'Total Won',
                    value: Formatters.currency(wallet.totalWon),
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 6),
                  _SmallStat(
                    label: 'Total Withdrawn',
                    value: Formatters.currency(wallet.totalWithdrawn),
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SmallStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.mono.copyWith(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.mono.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
