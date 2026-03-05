import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/sidebar.dart';

/// Main app layout with sidebar navigation.
/// Wraps all authenticated routes via ShellRoute.
class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Row(
        children: [
          const Sidebar(),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(child: child),
        ],
      ),
    );
  }
}
