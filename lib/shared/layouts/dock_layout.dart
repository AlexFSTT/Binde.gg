import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/dock.dart';
import '../widgets/status_bar.dart';

class DockLayout extends StatefulWidget {
  final Widget child;
  const DockLayout({super.key, required this.child});

  @override
  State<DockLayout> createState() => _DockLayoutState();
}

class _DockLayoutState extends State<DockLayout> {
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    _sendHeartbeat();
    _heartbeat = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _sendHeartbeat(),
    );
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    super.dispose();
  }

  /// Update last_online on the current user's profile.
  Future<void> _sendHeartbeat() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;

      await SupabaseConfig.client
          .from('profiles')
          .update({'last_online': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId);
    } catch (_) {
      // Silent fail — non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.5),
                  radius: 1.2,
                  colors: [AppColors.primary.withValues(alpha: 0.04), AppColors.bgBase],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, -0.8),
                  radius: 0.8,
                  colors: [AppColors.accent.withValues(alpha: 0.02), Colors.transparent],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 44, bottom: 90),
              child: widget.child,
            ),
          ),

          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: StatusBar(),
          ),

          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Dock(),
          ),
        ],
      ),
    );
  }
}
