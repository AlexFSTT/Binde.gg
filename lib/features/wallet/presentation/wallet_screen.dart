import 'package:flutter/material.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/errors/result.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/repositories/wallet_repository.dart';
import 'widgets/balance_overview.dart';
import 'widgets/wallet_actions.dart';
import 'widgets/transaction_history.dart';
import '../../../shared/widgets/glass_card.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _walletRepo = WalletRepository();

  WalletModel? _wallet;
  bool _isLoading = true;
  String? _error;

  String get _userId => SupabaseConfig.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _walletRepo.getWallet(_userId);

    if (!mounted) return;

    result.when(
      success: (wallet) => setState(() {
        _wallet = wallet;
        _isLoading = false;
      }),
      failure: (msg, _) => setState(() {
        _error = msg;
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _wallet == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load wallet',
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(_error ?? 'Unknown error',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadWallet,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return GlassPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page Title ─────────────────────────
            Text('Wallet', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text(
              'Manage your funds and view transaction history',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textTertiary),
            ),

            const SizedBox(height: 28),

            // ── Balance Overview ────────────────────
            BalanceOverview(wallet: _wallet!),

            const SizedBox(height: 24),

            // ── Quick Actions ──────────────────────
            const WalletActions(),

            const SizedBox(height: 28),

            // ── Transaction History ────────────────
            TransactionHistory(userId: _userId),
          ],
        ),
      ),
    );
  }
}
