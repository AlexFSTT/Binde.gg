import 'package:flutter/material.dart';

/// BINDE.GG brand color palette.
/// CS2-inspired dark theme — tactical teal, military amber, navy backgrounds.
class AppColors {
  AppColors._();

  // ── Brand ───────────────────────────────────────────
  static const Color primary = Color(0xFF3DAFB8);       // CS2 teal
  static const Color primaryHover = Color(0xFF4FC4CD);   // Lighter teal on hover
  static const Color primaryMuted = Color(0xFF132D30);   // Dark teal for muted backgrounds
  static const Color accent = Color(0xFFE8A33E);         // CS2 amber/gold

  // ── Backgrounds ─────────────────────────────────────
  static const Color bgBase = Color(0xFF0B0D12);         // Deep navy-black
  static const Color bgSurface = Color(0xFF111620);      // Card/panel backgrounds
  static const Color bgSurfaceHover = Color(0xFF182030); // Hover state on surfaces
  static const Color bgSurfaceActive = Color(0xFF1E2838);// Active/pressed state
  static const Color bgElevated = Color(0xFF1A2130);     // Elevated panels, popups

  // ── Text ────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE8ECF2);    // Warm white
  static const Color textSecondary = Color(0xFF8A96A8);  // Muted blue-grey
  static const Color textTertiary = Color(0xFF5A6578);   // Hint text
  static const Color textDisabled = Color(0xFF3A4458);   // Disabled state

  // ── Borders ─────────────────────────────────────────
  static const Color border = Color(0xFF1E2A3A);         // Default border
  static const Color borderSubtle = Color(0xFF162030);   // Subtle separators
  static const Color borderFocus = primary;               // Focus rings

  // ── Status ──────────────────────────────────────────
  static const Color success = Color(0xFF4ADE80);         // Green — wins, linked, good
  static const Color successMuted = Color(0xFF0D2818);    // Muted green bg
  static const Color warning = Color(0xFFE8A33E);         // Amber — caution, streaks
  static const Color warningMuted = Color(0xFF2A1E0A);    // Muted amber bg
  static const Color danger = Color(0xFFEF4444);          // Red — losses, errors
  static const Color dangerMuted = Color(0xFF2A0E0E);     // Muted red bg
  static const Color info = Color(0xFF5D9FCC);            // CT-side blue — info, links
  static const Color infoMuted = Color(0xFF0E1C2A);       // Muted blue bg

  // ── Match Status ────────────────────────────────────
  static const Color statusLive = Color(0xFFEF4444);      // Live match — red pulse
  static const Color statusWaiting = warning;              // Waiting — amber
  static const Color statusVeto = info;                    // Veto phase — blue
  static const Color statusFinished = success;             // Finished — green
}
