import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// macOS-style glass card that wraps page content.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassCard({super.key, required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 32, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgSurface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 0.5)),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A page-level glass container that fills available space.
class GlassPage extends StatelessWidget {
  final Widget child;
  const GlassPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: child,
    );
  }
}
