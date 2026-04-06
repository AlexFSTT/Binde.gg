import 'package:flutter/material.dart';
import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _client = SupabaseConfig.client;
  String get _userId => SupabaseConfig.auth.currentUser!.id;

  int _currentTier = 0;
  bool _isYearly = false;
  bool _isLoading = true;
  List<_Plan> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _client.from('profiles').select('subscription_tier').eq('id', _userId).single();
      final plans = await _client.from('subscription_plans').select().eq('is_active', true).order('tier');
      if (!mounted) return;
      setState(() {
        _currentTier = profile['subscription_tier'] as int? ?? 0;
        _plans = (plans as List).map((p) => _Plan.fromJson(p)).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: AppColors.bgBase,
          body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    return GlassPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            // ── Header ──────────────────────────────
            const SizedBox(height: 12),
            Text('Choose Your Plan', style: AppTextStyles.h1.copyWith(fontSize: 32)),
            const SizedBox(height: 8),
            Text('Unlock competitive rewards, exclusive features, and real prizes.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center),

            const SizedBox(height: 24),

            // ── Billing toggle ──────────────────────
            _BillingToggle(
              isYearly: _isYearly,
              onChanged: (v) => setState(() => _isYearly = v),
            ),

            const SizedBox(height: 32),

            // ── Plan Cards ──────────────────────────
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _plans.map((plan) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _PlanCard(
                        plan: plan,
                        isYearly: _isYearly,
                        isCurrent: _currentTier == plan.tier,
                        isUpgrade: plan.tier > _currentTier,
                        onSubscribe: () => _handleSubscribe(plan),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ── Feature comparison table ────────────
            _buildComparisonTable(),

            const SizedBox(height: 32),

            // ── FAQ / Info ──────────────────────────
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable() {
    const features = [
      ('Casual Lobbies', true, true, true),
      ('Leaderboard Access', true, true, true),
      ('Basic Profile', true, true, true),
      ('Bcoin Match Rewards', false, true, true),
      ('Lower Entry Fees (-25%)', false, true, true),
      ('Priority Matchmaking', false, true, true),
      ('Monthly Bcoin Bonus', false, true, true),
      ('Custom Profile Banner', false, true, true),
      ('Win PC Components & Peripherals', false, false, true),
      ('Top 5 Ladder = Real Money', false, false, true),
      ('Animated Profile Frame', false, false, true),
      ('Exclusive Tournaments', false, false, true),
      ('Priority Support', false, false, true),
      ('Early Access to Features', false, false, true),
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      decoration: BoxDecoration(
        color: AppColors.bgSurface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: AppColors.bgSurfaceActive,
            child: Row(children: [
              Expanded(flex: 3, child: Text('Feature', style: AppTextStyles.label.copyWith(fontSize: 12))),
              Expanded(child: Center(child: Text('Free', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 11)))),
              Expanded(child: Center(child: Text('Premium', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11)))),
              Expanded(child: Center(child: Text('Plus', style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 11)))),
            ]),
          ),
          ...features.map((f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
            child: Row(children: [
              Expanded(flex: 3, child: Text(f.$1, style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary, fontSize: 12))),
              Expanded(child: Center(child: _checkIcon(f.$2))),
              Expanded(child: Center(child: _checkIcon(f.$3))),
              Expanded(child: Center(child: _checkIcon(f.$4))),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _checkIcon(bool has) => Icon(
    has ? Icons.check_circle_rounded : Icons.remove_rounded,
    size: 16,
    color: has ? AppColors.success : AppColors.border,
  );

  Widget _buildInfoSection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('How it works', style: AppTextStyles.label.copyWith(fontSize: 14)),
          ]),
          const SizedBox(height: 16),
          _infoItem(Icons.monetization_on_rounded, AppColors.accent,
              'Premium', 'Compete in Bcoin-rewarded matches with lower entry fees. Earn monthly Bcoin bonuses and unlock premium profile features.'),
          const SizedBox(height: 12),
          _infoItem(Icons.emoji_events_rounded, AppColors.warning,
              'Premium Plus Ladder', 'Climb the Premium Plus ladder for real rewards. Top players each season win PC components, gaming peripherals, and the top 5 earn real money prizes.'),
          const SizedBox(height: 12),
          _infoItem(Icons.star_rounded, AppColors.accent,
              'Exclusive Badge & Frame', 'Premium Plus members get a golden animated frame around their profile picture and an exclusive badge visible to all players.'),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, Color color, String title, String desc) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTextStyles.label.copyWith(fontSize: 12)),
        const SizedBox(height: 2),
        Text(desc, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary, fontSize: 11, height: 1.4)),
      ])),
    ]);
  }

  Future<void> _handleSubscribe(_Plan plan) async {
    if (plan.tier == 0) return; // Can't subscribe to free
    if (plan.tier <= _currentTier) return; // Already on this or higher

    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border)),
      title: Text('Subscribe to ${plan.displayName}', style: AppTextStyles.h3),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(plan.tier == 2 ? Icons.workspace_premium : Icons.star_rounded,
            size: 48, color: plan.tier == 2 ? AppColors.accent : AppColors.primary),
        const SizedBox(height: 16),
        Text(plan.displayName, style: AppTextStyles.h2.copyWith(
            color: plan.tier == 2 ? AppColors.accent : AppColors.primary)),
        const SizedBox(height: 8),
        Text(_isYearly
            ? '€${plan.priceYearly.toStringAsFixed(2)}/year'
            : '€${plan.priceMonthly.toStringAsFixed(2)}/month',
            style: AppTextStyles.mono.copyWith(fontSize: 22, color: AppColors.textPrimary)),
        if (_isYearly) ...[
          const SizedBox(height: 4),
          Text('Save €${((plan.priceMonthly * 12) - plan.priceYearly).toStringAsFixed(2)}/year',
              style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        Text('Payment integration coming soon.\nYour subscription will be activated automatically.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: AppColors.textTertiary))),
      ],
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// BILLING TOGGLE
// ═══════════════════════════════════════════════════════════

class _BillingToggle extends StatelessWidget {
  final bool isYearly;
  final ValueChanged<bool> onChanged;
  const _BillingToggle({required this.isYearly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _toggleBtn('Monthly', !isYearly, () => onChanged(false)),
        _toggleBtn('Yearly', isYearly, () => onChanged(true), badge: 'SAVE 17%'),
      ]),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap, {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: AppTextStyles.label.copyWith(
              fontSize: 12, color: active ? AppColors.primary : AppColors.textTertiary)),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4)),
              child: Text(badge, style: AppTextStyles.caption.copyWith(
                  fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.success)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PLAN CARD
// ═══════════════════════════════════════════════════════════

class _PlanCard extends StatefulWidget {
  final _Plan plan;
  final bool isYearly, isCurrent, isUpgrade;
  final VoidCallback onSubscribe;
  const _PlanCard({required this.plan, required this.isYearly,
      required this.isCurrent, required this.isUpgrade, required this.onSubscribe});
  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final isPP = p.tier == 2;
    final isPrem = p.tier == 1;
    final accentColor = isPP ? AppColors.accent : isPrem ? AppColors.primary : AppColors.textTertiary;
    final price = widget.isYearly ? p.priceYearly : p.priceMonthly;
    final period = widget.isYearly ? '/year' : '/mo';
    final features = p.features;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isPP && _hovered ? AppColors.accent.withValues(alpha: 0.04)
              : _hovered ? AppColors.bgSurfaceHover : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isCurrent ? accentColor.withValues(alpha: 0.5)
                : isPP ? AppColors.accent.withValues(alpha: _hovered ? 0.4 : 0.2)
                : _hovered ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
            width: widget.isCurrent || isPP ? 1.5 : 1),
          boxShadow: isPP || _hovered ? [
            BoxShadow(color: accentColor.withValues(alpha: isPP ? 0.08 : 0.04),
                blurRadius: 20, offset: const Offset(0, 4)),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge row
            Row(children: [
              if (isPP)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE8A33E), Color(0xFFD4891F)]),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text('MOST POPULAR', style: AppTextStyles.caption.copyWith(
                      fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
                )
              else if (widget.isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text('CURRENT PLAN', style: AppTextStyles.caption.copyWith(
                      fontSize: 8, fontWeight: FontWeight.w800, color: accentColor, letterSpacing: 0.8)),
                ),
              const Spacer(),
              Icon(isPP ? Icons.workspace_premium : isPrem ? Icons.star_rounded : Icons.person_rounded,
                  size: 22, color: accentColor),
            ]),

            const SizedBox(height: 16),

            // Plan name
            Text(p.displayName, style: AppTextStyles.h2.copyWith(
                fontSize: 22, color: accentColor)),
            const SizedBox(height: 8),

            // Price
            if (p.tier == 0) ...[
              Text('Free', style: AppTextStyles.mono.copyWith(
                  fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Text('forever', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
            ] else ...[
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('€${price.toStringAsFixed(2)}',
                    style: AppTextStyles.mono.copyWith(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Padding(padding: const EdgeInsets.only(bottom: 4),
                    child: Text(period, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary))),
              ]),
              if (widget.isYearly)
                Text('€${(p.priceMonthly * 12 - p.priceYearly).toStringAsFixed(0)} saved vs monthly',
                    style: AppTextStyles.caption.copyWith(color: AppColors.success, fontSize: 10)),
            ],

            const SizedBox(height: 20),

            // CTA Button
            if (widget.isCurrent)
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2))),
                child: Center(child: Text('Current Plan', style: AppTextStyles.label.copyWith(
                    color: accentColor, fontSize: 13))),
              )
            else if (widget.isUpgrade)
              GestureDetector(
                onTap: widget.onSubscribe,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _hovered ? accentColor : accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3))),
                  child: Center(child: Text(
                    p.tier == 0 ? 'Get Started' : 'Upgrade Now',
                    style: AppTextStyles.label.copyWith(
                        color: _hovered ? Colors.white : accentColor, fontSize: 13))),
                ),
              )
            else
              const SizedBox(height: 42), // spacer for free if on higher plan

            const SizedBox(height: 20),

            // Features list
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_rounded, size: 14, color: accentColor),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary, fontSize: 12, height: 1.3))),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

class _Plan {
  final String id, name, displayName;
  final int tier;
  final double priceMonthly, priceYearly;
  final List<String> features;
  final String? badgeColor, frameStyle;

  _Plan({required this.id, required this.name, required this.displayName,
      required this.tier, required this.priceMonthly, required this.priceYearly,
      required this.features, this.badgeColor, this.frameStyle});

  factory _Plan.fromJson(Map<String, dynamic> json) {
    final feats = json['features'];
    List<String> featureList = [];
    if (feats is List) featureList = feats.map((e) => e.toString()).toList();
    if (feats is String) featureList = [feats];

    return _Plan(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      tier: json['tier'] as int? ?? 0,
      priceMonthly: (json['price_monthly'] as num?)?.toDouble() ?? 0,
      priceYearly: (json['price_yearly'] as num?)?.toDouble() ?? 0,
      features: featureList,
      badgeColor: json['badge_color'] as String?,
      frameStyle: json['frame_style'] as String?,
    );
  }
}
