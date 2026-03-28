import 'package:flutter/material.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _client = SupabaseConfig.client;
  String get _userId => SupabaseConfig.auth.currentUser!.id;

  int _bcoins = 0;
  List<_ShopItem> _coinPacks = [];
  List<_BcoinTx> _transactions = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      // Balance
      final profile = await _client
          .from('profiles')
          .select('bcoins')
          .eq('id', _userId)
          .single();

      // Shop items
      final items = await _client
          .from('shop_items')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      // Recent transactions
      final txData = await _client
          .from('bcoin_transactions')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(20);

      if (!mounted) return;
      setState(() {
        _bcoins = profile['bcoins'] as int? ?? 0;
        _coinPacks = (items as List)
            .where((i) => i['category'] == 'coins')
            .map((i) => _ShopItem.fromJson(i))
            .toList();
        _transactions =
            (txData as List).map((t) => _BcoinTx.fromJson(t)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Shop] Error: $e');
      if (mounted) setState(() => _isLoading = false);
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

    return GlassPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header + Balance ──────────────────────
            _buildHeader(),
            const SizedBox(height: 28),

            // ── Tab Bar ──────────────────────────────
            _buildTabBar(),
            const SizedBox(height: 20),

            // ── Content ──────────────────────────────
            if (_selectedTab == 0) _buildCoinPacks(),
            if (_selectedTab == 1) _buildProducts(),
            if (_selectedTab == 2) _buildTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Title
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_rounded,
                    size: 24, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('Shop', style: AppTextStyles.h2),
              ],
            ),
            const SizedBox(height: 4),
            Text('Purchase Bcoins and items',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary)),
          ],
        ),

        const Spacer(),

        // Bcoin Balance Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withValues(alpha: 0.12),
                AppColors.bgSurface,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BcoinIcon(size: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Your Balance',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary, fontSize: 10)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_bcoins',
                          style: AppTextStyles.mono.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent)),
                      const SizedBox(width: 4),
                      Text('B',
                          style: AppTextStyles.mono.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent.withValues(alpha: 0.6))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    const tabs = ['Coin Packs', 'Products', 'History'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final isActive = i == _selectedTab;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = i),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.border),
                ),
                child: Text(tabs[i],
                    style: AppTextStyles.label.copyWith(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        fontSize: 12)),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── COIN PACKS ──────────────────────────────────────

  Widget _buildCoinPacks() {
    if (_coinPacks.isEmpty) {
      return _emptyState(
          'No coin packs available', Icons.monetization_on_outlined);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Purchase Bcoins',
            style: AppTextStyles.label.copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Text('Use Bcoins to enter matches, buy items, and unlock features.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 24),

        // Uniform grid — all cards same size, centered
        LayoutBuilder(
          builder: (context, constraints) {
            final count = _coinPacks.length;
            const spacing = 16.0;
            final totalSpacing = spacing * (count - 1);
            final cardWidth = ((constraints.maxWidth - totalSpacing) / count)
                .clamp(160.0, 220.0);

            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(count, (i) {
                  return Padding(
                    padding:
                        EdgeInsets.only(right: i < count - 1 ? spacing : 0),
                    child: SizedBox(
                      width: cardWidth,
                      child: _CoinPackCard(
                        item: _coinPacks[i],
                        onBuy: () => _handleBuyCoinPack(_coinPacks[i]),
                        isHighlighted:
                            _coinPacks[i].metadata['badge'] == 'best_value',
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── PRODUCTS ────────────────────────────────────────

  Widget _buildProducts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.shopping_bag_rounded,
              size: 48, color: AppColors.textTertiary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Coming Soon',
              style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Cosmetics, boosts, and exclusive items will be available here.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── TRANSACTION HISTORY ─────────────────────────────

  Widget _buildTransactions() {
    if (_transactions.isEmpty) {
      return _emptyState('No transactions yet', Icons.receipt_long_rounded);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.bgSurfaceActive,
            child: Row(
              children: [
                SizedBox(width: 120, child: _th('Date')),
                SizedBox(width: 100, child: _th('Type')),
                Expanded(child: _th('Description')),
                SizedBox(
                    width: 80, child: _th('Amount', align: TextAlign.right)),
                SizedBox(
                    width: 80, child: _th('Balance', align: TextAlign.right)),
              ],
            ),
          ),
          ..._transactions.map((tx) => _TxRow(tx: tx)),
        ],
      ),
    );
  }

  Widget _th(String label, {TextAlign align = TextAlign.left}) {
    return Text(label,
        textAlign: align,
        style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary, letterSpacing: 0.5, fontSize: 10));
  }

  Widget _emptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 40, color: AppColors.textTertiary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Future<void> _handleBuyCoinPack(_ShopItem pack) async {
    // For now, show coming soon dialog — real payment integration later
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Purchase ${pack.name}', style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BcoinIcon(size: 48),
            const SizedBox(height: 16),
            Text(pack.name,
                style: AppTextStyles.h2.copyWith(color: AppColors.accent)),
            const SizedBox(height: 8),
            Text('€${pack.priceEur?.toStringAsFixed(2) ?? "0.00"}',
                style: AppTextStyles.mono
                    .copyWith(fontSize: 22, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Text(
                'Payment integration coming soon.\nBcoins will be credited automatically.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close',
                  style: TextStyle(color: AppColors.textTertiary))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// BCOIN ICON
// ═══════════════════════════════════════════════════════════

class _BcoinIcon extends StatelessWidget {
  final double size;
  const _BcoinIcon({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8A33E), Color(0xFFD4891F)],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: size * 0.3,
          ),
        ],
      ),
      child: Center(
        child: Text('B',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.5,
              fontWeight: FontWeight.w900,
            )),
      ),
    );
  }
}

/// Public Bcoin icon for use in other screens (dock, profile, etc.)
class BcoinIcon extends StatelessWidget {
  final double size;
  const BcoinIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8A33E), Color(0xFFD4891F)],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: size * 0.3,
          ),
        ],
      ),
      child: Center(
        child: Text('B',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.5,
              fontWeight: FontWeight.w900,
            )),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// COIN PACK CARD
// ═══════════════════════════════════════════════════════════

class _CoinPackCard extends StatefulWidget {
  final _ShopItem item;
  final VoidCallback onBuy;
  final bool isHighlighted;
  const _CoinPackCard(
      {required this.item, required this.onBuy, this.isHighlighted = false});
  @override
  State<_CoinPackCard> createState() => _CoinPackCardState();
}

class _CoinPackCardState extends State<_CoinPackCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final bcoinsAmount = item.metadata['bcoins'] as int? ?? 0;
    final badge = item.metadata['badge'] as String?;
    final hl = widget.isHighlighted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onBuy,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.bgSurfaceHover
                : hl
                    ? AppColors.accent.withValues(alpha: 0.04)
                    : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hl
                  ? AppColors.accent.withValues(alpha: _hovered ? 0.6 : 0.35)
                  : _hovered
                      ? AppColors.accent.withValues(alpha: 0.3)
                      : AppColors.border,
              width: hl ? 1.5 : 1,
            ),
            boxShadow: _hovered || hl
                ? [
                    BoxShadow(
                      color: AppColors.accent
                          .withValues(alpha: _hovered ? 0.12 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _badgeColor(badge).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _badgeColor(badge).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    badge.replaceAll('_', ' ').toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: _badgeColor(badge)),
                  ),
                )
              else
                const SizedBox(height: 22), // placeholder height

              const SizedBox(height: 16),

              // Bcoin icon (larger)
              _BcoinIcon(size: 52),
              const SizedBox(height: 16),

              // Amount
              Text('$bcoinsAmount',
                  style: AppTextStyles.mono.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent)),
              const SizedBox(height: 2),
              Text('Bcoins',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      letterSpacing: 0.5)),

              const SizedBox(height: 20),

              // Price button
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _hovered
                      ? AppColors.accent
                      : hl
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : AppColors.bgSurfaceActive,
                  borderRadius: BorderRadius.circular(10),
                  border: hl && !_hovered
                      ? Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2))
                      : null,
                ),
                child: Text(
                  '€${item.priceEur?.toStringAsFixed(2) ?? "0.00"}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.mono.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _hovered
                          ? Colors.white
                          : hl
                              ? AppColors.accent
                              : AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _badgeColor(String badge) => switch (badge) {
        'best_value' => AppColors.success,
        'popular' => AppColors.info,
        'ultimate' => const Color(0xFF9B59B6),
        'pro' => AppColors.accent,
        _ => AppColors.textTertiary,
      };
}

// ═══════════════════════════════════════════════════════════
// TRANSACTION ROW
// ═══════════════════════════════════════════════════════════

class _TxRow extends StatelessWidget {
  final _BcoinTx tx;
  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isPositive = tx.amount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(
                '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary, fontSize: 11),
              )),
          SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _typeColor(tx.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tx.type.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                        color: _typeColor(tx.type),
                        fontWeight: FontWeight.w700,
                        fontSize: 9)),
              )),
          Expanded(
              child: Text(tx.description ?? '-',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis)),
          SizedBox(
              width: 80,
              child: Text(
                '${isPositive ? "+" : ""}${tx.amount}',
                textAlign: TextAlign.right,
                style: AppTextStyles.mono.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPositive ? AppColors.success : AppColors.danger),
              )),
          SizedBox(
              width: 80,
              child: Text(
                '${tx.balanceAfter}',
                textAlign: TextAlign.right,
                style: AppTextStyles.mono
                    .copyWith(fontSize: 11, color: AppColors.textTertiary),
              )),
        ],
      ),
    );
  }

  Color _typeColor(String type) => switch (type) {
        'purchase' || 'reward' || 'winnings' || 'refund' => AppColors.success,
        'entry_fee' || 'shop_purchase' => AppColors.accent,
        'gift' => AppColors.info,
        _ => AppColors.textTertiary,
      };
}

// ═══════════════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════════════

class _ShopItem {
  final String id, name, category;
  final String? description, imageUrl;
  final int? priceBcoins;
  final double? priceEur;
  final Map<String, dynamic> metadata;

  _ShopItem(
      {required this.id,
      required this.name,
      required this.category,
      this.description,
      this.imageUrl,
      this.priceBcoins,
      this.priceEur,
      this.metadata = const {}});

  factory _ShopItem.fromJson(Map<String, dynamic> json) => _ShopItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'general',
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        priceBcoins: json['price_bcoins'] as int?,
        priceEur: (json['price_eur'] as num?)?.toDouble(),
        metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      );
}

class _BcoinTx {
  final String id, type;
  final int amount, balanceAfter;
  final String? description;
  final DateTime createdAt;

  _BcoinTx(
      {required this.id,
      required this.type,
      required this.amount,
      required this.balanceAfter,
      this.description,
      required this.createdAt});

  factory _BcoinTx.fromJson(Map<String, dynamic> json) => _BcoinTx(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: json['amount'] as int,
        balanceAfter: json['balance_after'] as int,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
