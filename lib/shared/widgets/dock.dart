import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class DockItem {
  final String route;
  final IconData icon;
  final String tooltip;
  final bool isPlay;
  const DockItem({required this.route, required this.icon, required this.tooltip, this.isPlay = false});
}

class Dock extends StatefulWidget {
  const Dock({super.key});
  @override
  State<Dock> createState() => _DockState();
}

class _DockState extends State<Dock> with TickerProviderStateMixin {
  static const _items = [
    DockItem(route: '/dashboard', icon: Icons.dashboard_rounded, tooltip: 'Dashboard'),
    DockItem(route: '/lobbies', icon: Icons.groups_rounded, tooltip: 'Lobbies'),
    DockItem(route: '/leaderboard', icon: Icons.leaderboard_rounded, tooltip: 'Leaderboard'),
    DockItem(route: '/play', icon: Icons.play_arrow_rounded, tooltip: 'Play', isPlay: true),
    DockItem(route: '/shop', icon: Icons.storefront_rounded, tooltip: 'Shop'),
    DockItem(route: '/subscription', icon: Icons.star_rounded, tooltip: 'Subscription'),
    DockItem(route: '/friends', icon: Icons.people_alt_rounded, tooltip: 'Friends'),
  ];

  static const double _baseItemSize = 44.0;
  static const double _playBaseSize = 56.0;
  static const double _dockPadding = 8.0;
  static const double _itemSpacing = 6.0;
  static const double _magnificationRadius = 120.0;

  double? _mouseX;
  final _profileKey = GlobalKey();
  OverlayEntry? _profileOverlay;

  @override
  void dispose() { _removeProfileOverlay(); super.dispose(); }

  void _removeProfileOverlay() { _profileOverlay?.remove(); _profileOverlay = null; }

  void _toggleProfileMenu() {
    if (_profileOverlay != null) { _removeProfileOverlay(); return; }
    final rb = _profileKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final pos = rb.localToGlobal(Offset.zero);
    final sz = rb.size;
    _profileOverlay = OverlayEntry(
      builder: (context) => _ProfilePopup(
        anchorPosition: pos, anchorSize: sz, onDismiss: _removeProfileOverlay,
        onNavigate: (route) { _removeProfileOverlay(); context.go(route); },
        onLogout: () { _removeProfileOverlay(); context.go('/login'); },
      ),
    );
    Overlay.of(context).insert(_profileOverlay!);
  }

  double _getScale(int index, bool isPlay) {
    if (_mouseX == null) return 1.0;
    double cx = _dockPadding;
    for (int i = 0; i < _items.length; i++) {
      final bs = _items[i].isPlay ? _playBaseSize : _baseItemSize;
      if (i == index) { cx += bs / 2; break; }
      cx += bs + _itemSpacing;
      if (i == 2 || i == 3) cx += 12.0;
    }
    final d = (_mouseX! - cx).abs();
    if (d > _magnificationRadius) return 1.0;
    return 1.0 + (0.45 * math.cos((d / _magnificationRadius) * math.pi / 2));
  }

  String _currentRoute(BuildContext context) => GoRouterState.of(context).uri.toString();

  @override
  Widget build(BuildContext context) {
    final cr = _currentRoute(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: MouseRegion(
          onHover: (e) => setState(() => _mouseX = e.localPosition.dx),
          onExit: (_) => setState(() => _mouseX = null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150), curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: _dockPadding, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgSurface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < 3; i++) ...[_buildDockItem(i, cr), if (i < 2) const SizedBox(width: _itemSpacing)],
                _sep(), _buildDockItem(3, cr), _sep(),
                for (int i = 4; i < 7; i++) ...[_buildDockItem(i, cr), if (i < 6) const SizedBox(width: _itemSpacing)],
                const SizedBox(width: _itemSpacing), _buildProfileButton(cr),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sep() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Container(width: 1, height: 32, margin: const EdgeInsets.only(bottom: 8), color: AppColors.border.withValues(alpha: 0.4)),
  );

  Widget _buildDockItem(int index, String cr) {
    final item = _items[index];
    final scale = _getScale(index, item.isPlay);
    final isActive = cr.startsWith(item.route);
    final bs = item.isPlay ? _playBaseSize : _baseItemSize;
    final size = bs * scale;
    return Tooltip(
      message: item.tooltip, preferBelow: false, verticalOffset: size / 2 + 12,
      decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border, width: 0.5)),
      textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
      child: GestureDetector(
        onTap: () { _removeProfileOverlay(); context.go(item.route); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut, width: size,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150), curve: Curves.easeOut, width: size, height: size,
              decoration: item.isPlay
                ? BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
                    boxShadow: [BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))])
                : BoxDecoration(borderRadius: BorderRadius.circular(12),
                    color: isActive ? AppColors.primary.withValues(alpha: 0.15) : AppColors.bgSurfaceHover.withValues(alpha: 0.5),
                    border: Border.all(color: isActive ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent, width: 0.5)),
              child: Icon(item.icon, size: item.isPlay ? size * 0.45 : size * 0.5,
                color: item.isPlay ? Colors.white : isActive ? AppColors.primary : AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(duration: const Duration(milliseconds: 200),
              width: isActive && !item.isPlay ? 4 : 0, height: isActive && !item.isPlay ? 4 : 0,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)),
          ]),
        ),
      ),
    );
  }

  Widget _buildProfileButton(String cr) {
    final isActive = cr.startsWith('/profile');
    final scale = _mouseX != null ? _getProfileScale() : 1.0;
    final size = _baseItemSize * scale;
    return Tooltip(
      message: 'Profile', preferBelow: false, verticalOffset: size / 2 + 12,
      decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border, width: 0.5)),
      textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
      child: GestureDetector(
        key: _profileKey, onTap: _toggleProfileMenu,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut, width: size,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(duration: const Duration(milliseconds: 150), curve: Curves.easeOut, width: size, height: size,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: isActive ? AppColors.primary.withValues(alpha: 0.15) : AppColors.bgSurfaceHover.withValues(alpha: 0.5),
                border: Border.all(color: isActive ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border.withValues(alpha: 0.3), width: 0.5)),
              child: Icon(Icons.person_rounded, size: size * 0.5, color: isActive ? AppColors.primary : AppColors.textSecondary)),
            const SizedBox(height: 4),
            AnimatedContainer(duration: const Duration(milliseconds: 200),
              width: isActive ? 4 : 0, height: isActive ? 4 : 0,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)),
          ]),
        ),
      ),
    );
  }

  double _getProfileScale() {
    if (_mouseX == null) return 1.0;
    double cx = _dockPadding;
    for (int i = 0; i < _items.length; i++) {
      cx += (_items[i].isPlay ? _playBaseSize : _baseItemSize) + _itemSpacing;
      if (i == 2 || i == 3) cx += 12.0;
    }
    cx += _baseItemSize / 2;
    final d = (_mouseX! - cx).abs();
    if (d > _magnificationRadius) return 1.0;
    return 1.0 + (0.45 * math.cos((d / _magnificationRadius) * math.pi / 2));
  }
}

class _ProfilePopup extends StatefulWidget {
  final Offset anchorPosition; final Size anchorSize;
  final VoidCallback onDismiss; final void Function(String) onNavigate; final VoidCallback onLogout;
  const _ProfilePopup({required this.anchorPosition, required this.anchorSize, required this.onDismiss, required this.onNavigate, required this.onLogout});

  @override
  State<_ProfilePopup> createState() => _ProfilePopupState();
}

class _ProfilePopupState extends State<_ProfilePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const w = 180.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: widget.onDismiss, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
        Positioned(
          left: widget.anchorPosition.dx + widget.anchorSize.width / 2 - w / 2,
          bottom: MediaQuery.of(context).size.height - widget.anchorPosition.dy + 12,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(width: w,
                  decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 0.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, -4))]),
                  clipBehavior: Clip.antiAlias,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(height: 4),
                    _PopupMenuItem(icon: Icons.person_rounded, label: 'Profile', onTap: () => widget.onNavigate('/profile/me')),
                    _PopupMenuItem(icon: Icons.settings_rounded, label: 'Settings', onTap: () => widget.onNavigate('/settings')),
                    _PopupMenuItem(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', onTap: () => widget.onNavigate('/wallet')),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Divider(height: 1, color: AppColors.border.withValues(alpha: 0.4))),
                    _PopupMenuItem(icon: Icons.logout_rounded, label: 'Logout', isDanger: true, onTap: widget.onLogout),
                    const SizedBox(height: 4),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PopupMenuItem extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool isDanger;
  const _PopupMenuItem({required this.icon, required this.label, required this.onTap, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    final defaultColor = isDanger ? AppColors.danger : AppColors.textPrimary;
    final hoverBg = isDanger
        ? AppColors.dangerMuted
        : AppColors.accent.withValues(alpha: 0.10);
    final hoverFg = isDanger ? AppColors.danger : AppColors.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: hoverBg,
          splashColor: isDanger
              ? AppColors.danger.withValues(alpha: 0.15)
              : AppColors.accent.withValues(alpha: 0.15),
          child: _HoverBuilder(
            builder: (isHovered) {
              final color = isHovered ? hoverFg : defaultColor;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Lightweight hover detection — changes icon/text color without managing state manually.
class _HoverBuilder extends StatefulWidget {
  final Widget Function(bool isHovered) builder;
  const _HoverBuilder({required this.builder});

  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<_HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered),
    );
  }
}
