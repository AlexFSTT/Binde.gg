import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/dock.dart';

class DockLayout extends StatelessWidget {
  final Widget child;
  const DockLayout({super.key, required this.child});

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
            child: Padding(padding: const EdgeInsets.only(bottom: 90), child: child),
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: Dock()),
        ],
      ),
    );
  }
}
