import 'dart:async';
import 'dart:ui';
import 'package:binde_gg/core/errors/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/models/active_presence.dart';
import '../../services/presence/presence_service.dart';
import 'presence_pill.dart';

enum ConnectionQuality { good, fair, poor, offline }

/// macOS-style top status bar with live platform indicators.
class StatusBar extends StatefulWidget {
  const StatusBar({super.key});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  ConnectionQuality _connection = ConnectionQuality.good;
  int _serversOnline = 0;
  int _usersOnline = 0;
  int _ongoingMatches = 0;
  int _unreadNotifs = 0;
  ActivePresence? _presence;
  StreamSubscription<ActivePresence?>? _presenceSub;

  final _notifRepo = NotificationRepository();
  Timer? _pingTimer;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _fetchPlatformStats();

    _pingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnection(),
    );
    _statsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchPlatformStats(),
    );

    // Subscribe to presence updates
    _presence = PresenceService().current;
    _presenceSub = PresenceService().presenceStream.listen((p) {
      if (mounted) setState(() => _presence = p);
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _statsTimer?.cancel();
    _presenceSub?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    try {
      final sw = Stopwatch()..start();
      await SupabaseConfig.client.from('profiles').select('id').limit(1);
      sw.stop();

      if (!mounted) return;

      final ms = sw.elapsedMilliseconds;
      setState(() {
        if (ms < 200) {
          _connection = ConnectionQuality.good;
        } else if (ms < 600) {
          _connection = ConnectionQuality.fair;
        } else {
          _connection = ConnectionQuality.poor;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _connection = ConnectionQuality.offline);
    }
  }

  Future<void> _fetchPlatformStats() async {
    final client = SupabaseConfig.client;

    // Fetch each stat independently to avoid type issues
    try {
      final usersRes = await client.from('profiles').select('id').gte(
          'last_online',
          DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 5))
              .toIso8601String());
      if (mounted) setState(() => _usersOnline = (usersRes as List).length);
    } catch (_) {}

    try {
      final matchesRes = await client
          .from('matches')
          .select('id')
          .inFilter('status', ['live', 'ready_check']);
      if (mounted) {
        setState(() => _ongoingMatches = (matchesRes as List).length);
      }
    } catch (_) {}

    try {
      final serversRes = await client
          .from('matches')
          .select('id')
          .inFilter('status', ['veto', 'ready_check', 'live']);
      if (mounted) setState(() => _serversOnline = (serversRes as List).length);
    } catch (_) {}

    // Notification count
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId != null) {
        final result = await _notifRepo.getUnreadCount(userId);
        if (mounted && result.isSuccess) {
          setState(() => _unreadNotifs = result.data!);
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshUnread() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;
    final result = await _notifRepo.getUnreadCount(userId);
    if (mounted && result.isSuccess) {
      setState(() => _unreadNotifs = result.data!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.bgSurface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.4),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Text(
                    'BINDE.GG',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),

                  // ── Presence pill (inserat aici) ────────────
                  if (_presence != null) ...[
                    const SizedBox(width: 12),
                    PresencePill(
                      presence: _presence!,
                      currentRoute: GoRouterState.of(context).matchedLocation,
                    ),
                  ],

                  _divider(),

                  // Connection
                  _ConnectionIndicator(quality: _connection),

                  _divider(),

                  // Servers
                  _StatIndicator(
                    icon: Icons.dns_rounded,
                    value: _serversOnline,
                    label: 'servers',
                    color: _serversOnline > 0
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),

                  _divider(),

                  // Users
                  _StatIndicator(
                    icon: Icons.people_rounded,
                    value: _usersOnline,
                    label: 'online',
                    color: _usersOnline > 0
                        ? AppColors.info
                        : AppColors.textTertiary,
                  ),

                  _divider(),

                  // Matches
                  _StatIndicator(
                    icon: Icons.sports_esports_rounded,
                    value: _ongoingMatches,
                    label: 'matches',
                    color: _ongoingMatches > 0
                        ? AppColors.warning
                        : AppColors.textTertiary,
                  ),

                  _divider(),

                  // Notifications bell
                  _NotificationBell(
                    unreadCount: _unreadNotifs,
                    onRefresh: _refreshUnread,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          width: 1,
          height: 14,
          color: AppColors.border.withValues(alpha: 0.4),
        ),
      );
}

/// Connection quality dot with label.
class _ConnectionIndicator extends StatelessWidget {
  final ConnectionQuality quality;
  const _ConnectionIndicator({required this.quality});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (quality) {
      ConnectionQuality.good => (AppColors.success, 'Stable'),
      ConnectionQuality.fair => (AppColors.warning, 'Fair'),
      ConnectionQuality.poor => (AppColors.danger, 'Unstable'),
      ConnectionQuality.offline => (AppColors.textTertiary, 'Offline'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulsingDot(color: color, pulse: quality == ConnectionQuality.good),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Animated pulsing dot.
class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _PulsingDot({required this.color, this.pulse = false});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.4,
      upperBound: 1.0,
    );
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulse && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: widget.pulse
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: _ctrl.value * 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

/// Small stat indicator: icon + number + label.
class _StatIndicator extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  const _StatIndicator({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          '$value',
          style: AppTextStyles.mono.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// NOTIFICATION BELL + DROPDOWN PANEL
// ═══════════════════════════════════════════════════════════

class _NotificationBell extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onRefresh;
  const _NotificationBell({required this.unreadCount, required this.onRefresh});
  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  OverlayEntry? _overlay;
  final _bellKey = GlobalKey();

  void _toggle() {
    if (_overlay != null) {
      _dismiss();
      return;
    }
    final rb = _bellKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final pos = rb.localToGlobal(Offset.zero);
    final size = rb.size;

    _overlay = OverlayEntry(
      builder: (context) => _NotifPanel(
        anchorX: pos.dx + size.width / 2,
        anchorY: pos.dy + size.height + 8,
        onDismiss: _dismiss,
        onChanged: widget.onRefresh,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _dismiss() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.unreadCount > 0;
    return GestureDetector(
      onTap: _toggle,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          key: _bellKey,
          width: 28,
          height: 22,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                  child: Icon(
                      hasUnread
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      size: 16,
                      color: hasUnread
                          ? AppColors.accent
                          : AppColors.textTertiary)),
              if (hasUnread)
                Positioned(
                    top: -2,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.bgSurface, width: 1.5)),
                      child: Text(
                          widget.unreadCount > 99
                              ? '99+'
                              : '${widget.unreadCount}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800)),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifPanel extends StatefulWidget {
  final double anchorX, anchorY;
  final VoidCallback onDismiss;
  final VoidCallback onChanged;
  const _NotifPanel({
    required this.anchorX,
    required this.anchorY,
    required this.onDismiss,
    required this.onChanged,
  });
  @override
  State<_NotifPanel> createState() => _NotifPanelState();
}

class _NotifPanelState extends State<_NotifPanel> {
  final _repo = NotificationRepository();
  List<NotificationModel> _notifs = [];
  bool _loading = true;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;
    final result = await _repo.getNotifications(userId, limit: 15);
    if (!mounted) return;
    result.when(
      success: (list) => setState(() {
        _notifs = list;
        _loading = false;
      }),
      failure: (_, __) => setState(() => _loading = false),
    );
  }

  Future<void> _markAllRead() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;
    await _repo.markAllAsRead(userId);
    if (!mounted) return;
    setState(() {
      _notifs = _notifs
          .map((n) => NotificationModel(
                id: n.id,
                userId: n.userId,
                type: n.type,
                title: n.title,
                message: n.message,
                data: n.data,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
    });
    widget.onChanged();
  }

  Future<void> _clearRead() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;
    await _repo.clearRead(userId);
    if (!mounted) return;
    setState(() => _notifs = _notifs.where((n) => !n.isRead).toList());
    widget.onChanged();
  }

  Future<void> _clearAll() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;
    await _repo.clearAll(userId);
    if (!mounted) return;
    setState(() => _notifs = []);
    widget.onChanged();
  }

  Future<void> _deleteOne(NotificationModel n) async {
    await _repo.deleteNotification(n.id);
    if (!mounted) return;
    setState(() => _notifs.removeWhere((x) => x.id == n.id));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    const w = 340.0;
    final left = (widget.anchorX - w / 2)
        .clamp(16.0, MediaQuery.of(context).size.width - w - 16);
    final hasUnread = _notifs.any((n) => !n.isRead);
    final hasRead = _notifs.any((n) => n.isRead);

    return Stack(children: [
      Positioned.fill(
          child: GestureDetector(
              onTap: widget.onDismiss,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand())),
      Positioned(
          left: left,
          top: widget.anchorY,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: w,
              constraints: const BoxConstraints(maxHeight: 420),
              decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ]),
              child: Stack(clipBehavior: Clip.none, children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  // ── Header ───────────────────────────────
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                      child: Row(children: [
                        const Icon(Icons.notifications_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Notifications',
                            style: AppTextStyles.label.copyWith(fontSize: 13)),
                        const Spacer(),
                        if (hasUnread)
                          TextButton(
                            onPressed: _markAllRead,
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 28),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            child: Text('Mark all read',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        // Inline 3-dot toggle
                        if (_notifs.isNotEmpty)
                          IconButton(
                            onPressed: () =>
                                setState(() => _menuOpen = !_menuOpen),
                            icon: Icon(Icons.more_horiz_rounded,
                                size: 16,
                                color: _menuOpen
                                    ? AppColors.primary
                                    : AppColors.textTertiary),
                            tooltip: 'More',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            splashRadius: 14,
                          ),
                      ])),
                  Container(
                      height: 1,
                      color: AppColors.border.withValues(alpha: 0.3)),

                  // ── Body ─────────────────────────────────
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary)))
                  else if (_notifs.isEmpty)
                    Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(children: [
                          Icon(Icons.notifications_off_rounded,
                              size: 28,
                              color: AppColors.textTertiary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text('No notifications',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textTertiary)),
                        ]))
                  else
                    Flexible(
                        child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _notifs.length,
                      itemBuilder: (context, i) => _NotifTile(
                          notif: _notifs[i],
                          onDelete: () => _deleteOne(_notifs[i]),
                          onTap: () async {
                            if (!_notifs[i].isRead) {
                              await _repo.markAsRead(_notifs[i].id);
                              widget.onChanged();
                            }
                            if (!context.mounted) return;
                            widget.onDismiss();
                            final data = _notifs[i].data;
                            switch (_notifs[i].type) {
                              case 'friend_request' || 'friend_accepted':
                                context.go('/friends');
                              case 'match_ready' || 'match_result':
                                final matchId = data['match_id'] as String?;
                                if (matchId != null) {
                                  context.go('/match/$matchId');
                                }
                              default:
                                break;
                            }
                          }),
                    )),
                ]),

                // ── Inline dropdown menu (inside panel) ──
                if (_menuOpen && _notifs.isNotEmpty)
                  Positioned(
                    right: 10,
                    top: 42,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (hasRead)
                          _MenuRow(
                            icon: Icons.done_all_rounded,
                            label: 'Clear read',
                            color: AppColors.textSecondary,
                            onTap: () {
                              setState(() => _menuOpen = false);
                              _clearRead();
                            },
                          ),
                        _MenuRow(
                          icon: Icons.delete_sweep_rounded,
                          label: 'Clear all',
                          color: AppColors.danger,
                          onTap: () {
                            setState(() => _menuOpen = false);
                            _clearAll();
                          },
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
          )),
    ]);
  }
}

/// Simple row used inside the inline dropdown menu.
class _MenuRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
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
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(widget.icon, size: 14, color: widget.color),
            const SizedBox(width: 10),
            Text(widget.label,
                style: AppTextStyles.bodySmall
                    .copyWith(fontSize: 12, color: widget.color)),
          ]),
        ),
      ),
    );
  }
}

class _NotifTile extends StatefulWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _NotifTile({
    required this.notif,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final notif = widget.notif;
    final (icon, color) = _iconForType(notif.type);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: notif.isRead
                    ? null
                    : AppColors.primary.withValues(alpha: 0.03),
                border: Border(
                    bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.2)))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 5, right: 8),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: notif.isRead
                          ? Colors.transparent
                          : AppColors.primary)),
              Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7)),
                  child: Icon(icon, size: 14, color: color)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(notif.title,
                        style: AppTextStyles.label.copyWith(
                            fontSize: 11,
                            color: notif.isRead
                                ? AppColors.textSecondary
                                : AppColors.textPrimary)),
                    const SizedBox(height: 1),
                    Text(notif.message,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary, fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ])),
              const SizedBox(width: 8),
              // Delete button on hover, time-ago otherwise
              SizedBox(
                width: 32,
                child: _hovered
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.close_rounded, size: 14),
                          color: AppColors.textTertiary,
                          hoverColor: AppColors.danger.withValues(alpha: 0.12),
                          tooltip: 'Delete',
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 26, minHeight: 26),
                          splashRadius: 14,
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Text(_timeAgo(notif.createdAt),
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary, fontSize: 9)),
                      ),
              ),
            ]),
          )),
    );
  }

  (IconData, Color) _iconForType(String type) => switch (type) {
        'friend_request' => (Icons.person_add_rounded, AppColors.info),
        'friend_accepted' => (Icons.people_rounded, AppColors.success),
        'match_ready' => (Icons.sports_esports_rounded, AppColors.accent),
        'match_result' => (Icons.emoji_events_rounded, AppColors.warning),
        'warning' => (Icons.warning_amber_rounded, AppColors.danger),
        'cooldown' => (Icons.timer_rounded, AppColors.warning),
        'reward' => (Icons.card_giftcard_rounded, AppColors.accent),
        'achievement' => (Icons.military_tech_rounded, AppColors.warning),
        'system' => (Icons.info_rounded, AppColors.info),
        _ => (Icons.notifications_rounded, AppColors.textTertiary),
      };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
