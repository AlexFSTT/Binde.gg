import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

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
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _statsTimer?.cancel();
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
      final usersRes = await client
          .from('profiles')
          .select('id')
          .gte('last_online',
              DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String());
      if (mounted) setState(() => _usersOnline = (usersRes as List).length);
    } catch (_) {}

    try {
      final matchesRes = await client
          .from('matches')
          .select('id')
          .inFilter('status', ['live', 'ready_check']);
      if (mounted) setState(() => _ongoingMatches = (matchesRes as List).length);
    } catch (_) {}

    try {
      final serversRes = await client
          .from('matches')
          .select('id')
          .inFilter('status', ['veto', 'ready_check', 'live']);
      if (mounted) setState(() => _serversOnline = (serversRes as List).length);
    } catch (_) {}
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
