import 'package:flutter/material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/transaction_model.dart';

/// Transaction history section with type filter and pagination.
class TransactionHistory extends StatefulWidget {
  final String userId;
  const TransactionHistory({super.key, required this.userId});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  final List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  String _filter = 'all';
  static const _pageSize = 15;

  static const _filters = [
    ('all', 'All'),
    ('deposit', 'Deposits'),
    ('withdrawal', 'Withdrawals'),
    ('entry_fee', 'Entry Fees'),
    ('winnings', 'Winnings'),
    ('refund', 'Refunds'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool reset = false}) async {
    if (reset) {
      _transactions.clear();
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore && !reset) return;

    setState(() => _isLoading = true);

    try {
      final client = SupabaseConfig.client;
      final from = _page * _pageSize;

      var query = client
          .from('wallet_transactions')
          .select()
          .eq('user_id', widget.userId);

      if (_filter != 'all') {
        query = query.eq('type', _filter);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(from, from + _pageSize - 1);

      if (!mounted) return;

      final entries =
          data.map((j) => TransactionModel.fromJson(j)).toList();

      setState(() {
        _isLoading = false;
        _transactions.addAll(entries);
        _page++;
        _hasMore = entries.length == _pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setFilter(String filter) {
    if (_filter == filter) return;
    _filter = filter;
    _loadTransactions(reset: true);
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
          // ── Header + Filters ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 18, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Text('Transactions',
                        style: AppTextStyles.label.copyWith(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 14),

                // Filter chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _filters.map((f) {
                    final isActive = _filter == f.$1;
                    return _FilterChip(
                      label: f.$2,
                      isActive: isActive,
                      onTap: () => _setFilter(f.$1),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderSubtle),

          // ── Table Header ─────────────────────────
          if (_transactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  SizedBox(
                      width: 100,
                      child: Text('TYPE',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8))),
                  Expanded(
                      child: Text('DESCRIPTION',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8))),
                  SizedBox(
                      width: 100,
                      child: Text('AMOUNT',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8))),
                  SizedBox(
                      width: 90,
                      child: Text('BALANCE',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8))),
                  SizedBox(
                      width: 80,
                      child: Text('STATUS',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8))),
                  SizedBox(
                      width: 90,
                      child: Text('DATE',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8))),
                ],
              ),
            ),

          // ── Transaction Rows ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _transactions.isEmpty && !_isLoading
                ? _EmptyState(filter: _filter)
                : Column(
                    children: [
                      ..._transactions
                          .map((tx) => _TransactionRow(tx: tx)),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        )
                      else if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: TextButton(
                              onPressed: _loadTransactions,
                              child: Text('Load more',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : _hovered
                    ? AppColors.bgSurfaceHover
                    : AppColors.bgSurfaceActive,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.bodySmall.copyWith(
              color: widget.isActive
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontWeight:
                  widget.isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final TransactionModel tx;
  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          // Type badge
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(_typeIcon, size: 14, color: _typeColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _typeLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Description
          Expanded(
            child: Text(
              tx.description ?? '-',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Amount
          SizedBox(
            width: 100,
            child: Text(
              '${tx.isCredit ? '+' : '-'}${Formatters.currency(tx.amount)}',
              textAlign: TextAlign.right,
              style: AppTextStyles.mono.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tx.isCredit ? AppColors.success : AppColors.danger,
              ),
            ),
          ),

          // Balance after
          SizedBox(
            width: 90,
            child: Text(
              Formatters.currency(tx.balanceAfter),
              textAlign: TextAlign.right,
              style: AppTextStyles.mono.copyWith(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ),

          // Status
          SizedBox(
            width: 80,
            child: Center(child: _StatusDot(status: tx.status)),
          ),

          // Date
          SizedBox(
            width: 90,
            child: Text(
              Formatters.timeAgo(tx.createdAt),
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _typeLabel => switch (tx.type) {
        'deposit' => 'Deposit',
        'withdrawal' => 'Withdraw',
        'entry_fee' => 'Entry Fee',
        'winnings' => 'Winnings',
        'refund' => 'Refund',
        'rake' => 'Rake',
        'bonus' => 'Bonus',
        _ => tx.type,
      };

  IconData get _typeIcon => switch (tx.type) {
        'deposit' => Icons.arrow_downward_rounded,
        'withdrawal' => Icons.arrow_upward_rounded,
        'entry_fee' => Icons.sports_esports_rounded,
        'winnings' => Icons.emoji_events_rounded,
        'refund' => Icons.replay_rounded,
        'rake' => Icons.percent_rounded,
        'bonus' => Icons.card_giftcard_rounded,
        _ => Icons.swap_horiz_rounded,
      };

  Color get _typeColor => switch (tx.type) {
        'deposit' => AppColors.success,
        'withdrawal' => AppColors.info,
        'entry_fee' => AppColors.warning,
        'winnings' => AppColors.success,
        'refund' => AppColors.info,
        'rake' => AppColors.textTertiary,
        'bonus' => AppColors.accent,
        _ => AppColors.textTertiary,
      };
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'completed' => (AppColors.success, 'Done'),
      'pending' => (AppColors.warning, 'Pending'),
      'processing' => (AppColors.info, 'Processing'),
      'failed' => (AppColors.danger, 'Failed'),
      'cancelled' => (AppColors.textTertiary, 'Cancelled'),
      'reversed' => (AppColors.danger, 'Reversed'),
      _ => (AppColors.textTertiary, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 40,
                color: AppColors.textTertiary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              filter == 'all'
                  ? 'No transactions yet'
                  : 'No ${filter.replaceAll('_', ' ')} transactions',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Your transaction history will appear here',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
