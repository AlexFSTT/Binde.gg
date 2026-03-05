import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Left branding panel shown on auth screens (login/register).
/// Features animated grid background, logo, tagline, and live stats.
class AuthBrandingPanel extends StatelessWidget {
  const AuthBrandingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
      ),
      child: Stack(
        children: [
          // ── Grid pattern background ──────────────────
          const _GridBackground(),

          // ── Radial glow ──────────────────────────────
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom right accent glow ─────────────────
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'B',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'BINDE.GG',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Tagline
                Text(
                  'Compete.',
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 44,
                    height: 1.1,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Wager.',
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 44,
                    height: 1.1,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Dominate.',
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 44,
                    height: 1.1,
                    color: AppColors.textTertiary,
                  ),
                ),

                const SizedBox(height: 32),

                // Description
                Text(
                  'The premier CS2 wagering platform.\nPut your skills on the line.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 48),

                // Live stats ticker
                const _StatsTicker(),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated grid background pattern.
class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    const spacing = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Random highlighted intersections
    final highlightPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15);

    final rng = Random(42); // Fixed seed for consistent pattern
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        if (rng.nextDouble() < 0.04) {
          canvas.drawCircle(Offset(x, y), 3, highlightPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fake live stats row (static for now, later wired to real data).
class _StatsTicker extends StatelessWidget {
  const _StatsTicker();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.circle,
          iconColor: AppColors.success,
          iconSize: 8,
          label: '2,847 online',
        ),
        const SizedBox(width: 24),
        _StatChip(
          icon: Icons.local_fire_department_rounded,
          iconColor: AppColors.warning,
          iconSize: 16,
          label: '€14.2K wagered today',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String label;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
