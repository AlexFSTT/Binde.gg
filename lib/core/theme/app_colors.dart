import 'package:flutter/material.dart';

/// BINDE.GG brand color palette.
/// Dark theme optimized for gaming UI.
class AppColors {
  AppColors._();

  // ── Brand ───────────────────────────────────────────
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryHover = Color(0xFF7F71EE);
  static const Color primaryMuted = Color(0xFF2D2654);
  static const Color accent = Color(0xFF00E5FF);

  // ── Backgrounds ─────────────────────────────────────
  static const Color bgBase = Color(0xFF0A0A0F);
  static const Color bgSurface = Color(0xFF12121A);
  static const Color bgSurfaceHover = Color(0xFF1A1A25);
  static const Color bgSurfaceActive = Color(0xFF22222F);
  static const Color bgElevated = Color(0xFF1E1E2A);

  // ── Text ────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFA0A0B5);
  static const Color textTertiary = Color(0xFF606075);
  static const Color textDisabled = Color(0xFF404055);

  // ── Borders ─────────────────────────────────────────
  static const Color border = Color(0xFF2A2A3A);
  static const Color borderSubtle = Color(0xFF1E1E2E);
  static const Color borderFocus = primary;

  // ── Status ──────────────────────────────────────────
  static const Color success = Color(0xFF00D26A);
  static const Color successMuted = Color(0xFF0A2E1A);
  static const Color warning = Color(0xFFFFC107);
  static const Color warningMuted = Color(0xFF2E2A0A);
  static const Color danger = Color(0xFFFF4757);
  static const Color dangerMuted = Color(0xFF2E0A0F);
  static const Color info = Color(0xFF00B4D8);
  static const Color infoMuted = Color(0xFF0A1E2E);

  // ── Match Status ────────────────────────────────────
  static const Color statusLive = Color(0xFFFF4757);
  static const Color statusWaiting = warning;
  static const Color statusVeto = info;
  static const Color statusFinished = success;
}
