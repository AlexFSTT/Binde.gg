import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Left branding panel for auth screens — CS2 tactical theme with live stats.
class AuthBrandingPanel extends StatefulWidget {
  const AuthBrandingPanel({super.key});

  @override
  State<AuthBrandingPanel> createState() => _AuthBrandingPanelState();
}

class _AuthBrandingPanelState extends State<AuthBrandingPanel>
    with TickerProviderStateMixin {
  // ── Live stats ─────────────────────────────────────
  int _playersOnline = 0;
  int _serversLive = 0;
  int _matchesLive = 0;
  double _wageredThisMonth = 0;
  bool _connected = false;
  Timer? _refreshTimer;

  // ── Animations ─────────────────────────────────────
  late final AnimationController _radarCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchStats(),
    );

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      lowerBound: 0.3,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final client = SupabaseConfig.client;
      final sw = Stopwatch()..start();
      await client.from('profiles').select('id').limit(1);
      sw.stop();

      final usersRes = await client
          .from('profiles')
          .select('id')
          .gte('last_online',
              DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String());

      final matchesRes = await client
          .from('matches')
          .select('id')
          .inFilter('status', ['live', 'ready_check', 'veto']);

      final serversRes = await client
          .from('matches')
          .select('id')
          .inFilter('status', ['live', 'veto', 'ready_check']);

      final now = DateTime.now().toUtc();
      final monthStart = DateTime.utc(now.year, now.month, 1).toIso8601String();
      final wageredRes = await client
          .from('matches')
          .select('total_pot')
          .eq('status', 'finished')
          .gte('finished_at', monthStart);

      double totalWagered = 0;
      for (final row in (wageredRes as List)) {
        totalWagered += (row['total_pot'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _connected = sw.elapsedMilliseconds < 2000;
        _playersOnline = (usersRes as List).length;
        _matchesLive = (matchesRes as List).length;
        _serversLive = (serversRes as List).length;
        _wageredThisMonth = totalWagered;
      });
    } catch (_) {
      if (mounted) setState(() => _connected = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          // ── CS2 Tactical Background ─────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_radarCtrl, _pulseCtrl]),
              builder: (context, child) => CustomPaint(
                painter: _TacticalBgPainter(
                  radarAngle: _radarCtrl.value * 2 * pi,
                  pulseValue: _pulseCtrl.value,
                ),
              ),
            ),
          ),

          // ── Teal glow center ────────────────────────
          Positioned(
            top: 80,
            right: -40,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('B',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('BINDE.GG',
                        style: AppTextStyles.h2.copyWith(
                            letterSpacing: 3, fontWeight: FontWeight.w800)),
                  ],
                ),

                const Spacer(flex: 2),

                // Tagline
                Text('Compete.',
                    style: AppTextStyles.h1.copyWith(
                        fontSize: 48,
                        height: 1.1,
                        color: AppColors.textPrimary)),
                Text('Wager.',
                    style: AppTextStyles.h1.copyWith(
                        fontSize: 48, height: 1.1, color: AppColors.primary)),
                Text('Dominate.',
                    style: AppTextStyles.h1.copyWith(
                        fontSize: 48, height: 1.1, color: AppColors.accent)),

                const SizedBox(height: 24),

                Text(
                  'The premier CS2 competitive wagering platform.\nPut your skills on the line.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textTertiary, height: 1.7),
                ),

                const Spacer(),

                // ── Live Status Bar ──────────────────
                _buildStatusBar(),

                const SizedBox(height: 32),

                Text(
                  '© 2026 BINDE.GG — All rights reserved',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.border.withValues(alpha: 0.4), width: 0.5),
          ),
          child: Row(
            children: [
              _StatusDot(
                  color: _connected ? AppColors.success : AppColors.danger,
                  pulse: _connected),
              const SizedBox(width: 8),
              Text(_connected ? 'Connected' : 'Offline',
                  style: AppTextStyles.caption.copyWith(
                      color: _connected ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 11)),
              _div(),
              _stat(Icons.dns_rounded, '$_serversLive', 'servers',
                  _serversLive > 0 ? AppColors.success : AppColors.textTertiary),
              _div(),
              _stat(Icons.people_rounded, '$_playersOnline', 'online',
                  _playersOnline > 0 ? AppColors.info : AppColors.textTertiary),
              _div(),
              _stat(Icons.sports_esports_rounded, '$_matchesLive', 'live',
                  _matchesLive > 0 ? AppColors.accent : AppColors.textTertiary),
              _div(),
              _stat(
                  Icons.paid_rounded,
                  _wageredThisMonth > 0
                      ? '€${_wageredThisMonth.toStringAsFixed(0)}'
                      : '€0',
                  'this month',
                  _wageredThisMonth > 0
                      ? AppColors.success
                      : AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(value,
            style: AppTextStyles.mono.copyWith(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 3),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(fontSize: 10, color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _div() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
          width: 1, height: 14,
          color: AppColors.border.withValues(alpha: 0.4)));
}

// ═════════════════════════════════════════════════════════════
// CS2 TACTICAL BACKGROUND PAINTER
// ═════════════════════════════════════════════════════════════

class _TacticalBgPainter extends CustomPainter {
  final double radarAngle;
  final double pulseValue;

  _TacticalBgPainter({required this.radarAngle, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawRadar(canvas, size);
    _drawCrosshair(canvas, size);
    _drawMapOutlines(canvas, size);
    _drawCornerBrackets(canvas, size);
    _drawFloatingParticles(canvas, size);
    _drawScanLines(canvas, size);
  }

  /// Fine tactical grid
  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.12)
      ..strokeWidth = 0.3;
    final majorPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      final isMajor = (x % (spacing * 4)) < 1;
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), isMajor ? majorPaint : paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      final isMajor = (y % (spacing * 4)) < 1;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), isMajor ? majorPaint : paint);
    }
  }

  /// Radar circle with sweep
  void _drawRadar(Canvas canvas, Size size) {
    final cx = size.width * 0.72;
    final cy = size.height * 0.32;
    final maxR = size.width * 0.22;

    // Concentric circles
    final circlePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), maxR * i / 4, circlePaint);
    }

    // Cross lines through center
    final crossPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), crossPaint);

    // Sweep line (rotating)
    final sweepPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final ex = cx + cos(radarAngle) * maxR;
    final ey = cy + sin(radarAngle) * maxR;
    canvas.drawLine(Offset(cx, cy), Offset(ex, ey), sweepPaint);

    // Sweep trail (fading arc)
    final sweepArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = maxR
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: radarAngle - 0.8,
        endAngle: radarAngle,
        colors: [
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.04),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR / 2));

    canvas.drawCircle(Offset(cx, cy), maxR / 2, sweepArc);

    // Blips (fixed seed random positions)
    final rng = Random(7);
    final blipPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.3 * pulseValue);
    for (int i = 0; i < 5; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = rng.nextDouble() * maxR * 0.85;
      canvas.drawCircle(
        Offset(cx + cos(angle) * dist, cy + sin(angle) * dist),
        2,
        blipPaint,
      );
    }

    // Center dot
    canvas.drawCircle(
        Offset(cx, cy), 3, Paint()..color = AppColors.primary.withValues(alpha: 0.4));
  }

  /// Crosshair element (subtle, bottom-left area)
  void _drawCrosshair(Canvas canvas, Size size) {
    final cx = size.width * 0.25;
    final cy = size.height * 0.65;
    const len = 18.0;
    const gap = 5.0;

    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.15 * pulseValue)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Four arms
    canvas.drawLine(Offset(cx - len, cy), Offset(cx - gap, cy), paint);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + len, cy), paint);
    canvas.drawLine(Offset(cx, cy - len), Offset(cx, cy - gap), paint);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + len), paint);

    // Tiny center dot
    canvas.drawCircle(Offset(cx, cy), 1.5,
        Paint()..color = AppColors.accent.withValues(alpha: 0.2));
  }

  /// de_dust2 map layout — minimalist line schematic
  void _drawMapOutlines(Canvas canvas, Size size) {
    // Scale & position: map fills ~65% of panel, centered
    final s = min(size.width, size.height) * 0.0028; // scale factor
    final ox = size.width * 0.12; // offset X
    final oy = size.height * 0.12; // offset Y

    final wallPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.015)
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final accentFill = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.012)
      ..style = PaintingStyle.fill;

    // ── A SITE (top-right) ──────────────────────────
    final aPath = Path();
    aPath.moveTo(ox + 220*s, oy + 20*s);
    aPath.lineTo(ox + 320*s, oy + 20*s);
    aPath.lineTo(ox + 320*s, oy + 50*s);
    aPath.lineTo(ox + 350*s, oy + 50*s);
    aPath.lineTo(ox + 350*s, oy + 130*s);
    aPath.lineTo(ox + 300*s, oy + 130*s);
    aPath.lineTo(ox + 300*s, oy + 110*s);
    aPath.lineTo(ox + 250*s, oy + 110*s);
    aPath.lineTo(ox + 250*s, oy + 130*s);
    aPath.lineTo(ox + 220*s, oy + 130*s);
    aPath.close();
    canvas.drawPath(aPath, fillPaint);
    canvas.drawPath(aPath, wallPaint);

    // ── LONG A (right side, vertical corridor) ──────
    final longPath = Path();
    longPath.moveTo(ox + 290*s, oy + 130*s);
    longPath.lineTo(ox + 320*s, oy + 130*s);
    longPath.lineTo(ox + 320*s, oy + 280*s);
    longPath.lineTo(ox + 350*s, oy + 280*s);
    longPath.lineTo(ox + 350*s, oy + 340*s);
    longPath.lineTo(ox + 290*s, oy + 340*s);
    longPath.close();
    canvas.drawPath(longPath, wallPaint);

    // Long Doors
    final ldPath = Path();
    ldPath.moveTo(ox + 290*s, oy + 280*s);
    ldPath.lineTo(ox + 320*s, oy + 280*s);
    ldPath.lineTo(ox + 320*s, oy + 310*s);
    ldPath.lineTo(ox + 290*s, oy + 310*s);
    ldPath.close();
    canvas.drawPath(ldPath, accentPaint);

    // ── T SPAWN (bottom) ────────────────────────────
    final tPath = Path();
    tPath.moveTo(ox + 150*s, oy + 340*s);
    tPath.lineTo(ox + 250*s, oy + 340*s);
    tPath.lineTo(ox + 250*s, oy + 400*s);
    tPath.lineTo(ox + 150*s, oy + 400*s);
    tPath.close();
    canvas.drawPath(tPath, wallPaint);
    canvas.drawPath(tPath, fillPaint);

    // ── MID (center corridor) ───────────────────────
    final midPath = Path();
    midPath.moveTo(ox + 180*s, oy + 130*s);
    midPath.lineTo(ox + 220*s, oy + 130*s);
    midPath.lineTo(ox + 220*s, oy + 340*s);
    midPath.lineTo(ox + 180*s, oy + 340*s);
    midPath.close();
    canvas.drawPath(midPath, wallPaint);

    // Mid Doors (iconic double doors)
    final mdRect = Rect.fromLTWH(ox + 185*s, oy + 200*s, 30*s, 8*s);
    canvas.drawRect(mdRect, accentPaint);

    // ── SHORT A / CATWALK ───────────────────────────
    final catPath = Path();
    catPath.moveTo(ox + 220*s, oy + 130*s);
    catPath.lineTo(ox + 250*s, oy + 130*s);
    catPath.lineTo(ox + 250*s, oy + 180*s);
    catPath.lineTo(ox + 220*s, oy + 220*s);
    canvas.drawPath(catPath, wallPaint);

    // ── CT SPAWN (top center) ───────────────────────
    final ctPath = Path();
    ctPath.moveTo(ox + 180*s, oy + 20*s);
    ctPath.lineTo(ox + 220*s, oy + 20*s);
    ctPath.lineTo(ox + 220*s, oy + 80*s);
    ctPath.lineTo(ox + 180*s, oy + 80*s);
    ctPath.close();
    canvas.drawPath(ctPath, wallPaint);
    canvas.drawPath(ctPath, fillPaint);

    // ── B TUNNELS (bottom-left) ─────────────────────
    final btPath = Path();
    btPath.moveTo(ox + 50*s, oy + 280*s);
    btPath.lineTo(ox + 120*s, oy + 280*s);
    btPath.lineTo(ox + 150*s, oy + 250*s);
    btPath.lineTo(ox + 150*s, oy + 340*s);
    btPath.lineTo(ox + 50*s, oy + 340*s);
    btPath.close();
    canvas.drawPath(btPath, wallPaint);

    // Upper tunnels connection
    final utPath = Path();
    utPath.moveTo(ox + 80*s, oy + 200*s);
    utPath.lineTo(ox + 120*s, oy + 200*s);
    utPath.lineTo(ox + 120*s, oy + 280*s);
    utPath.lineTo(ox + 80*s, oy + 280*s);
    utPath.close();
    canvas.drawPath(utPath, wallPaint);

    // ── B SITE (top-left) ───────────────────────────
    final bPath = Path();
    bPath.moveTo(ox + 20*s, oy + 40*s);
    bPath.lineTo(ox + 140*s, oy + 40*s);
    bPath.lineTo(ox + 140*s, oy + 70*s);
    bPath.lineTo(ox + 160*s, oy + 70*s);
    bPath.lineTo(ox + 160*s, oy + 160*s);
    bPath.lineTo(ox + 80*s, oy + 160*s);
    bPath.lineTo(ox + 80*s, oy + 130*s);
    bPath.lineTo(ox + 20*s, oy + 130*s);
    bPath.close();
    canvas.drawPath(bPath, accentFill);
    canvas.drawPath(bPath, accentPaint);

    // B Doors
    final bdRect = Rect.fromLTWH(ox + 130*s, oy + 135*s, 8*s, 25*s);
    canvas.drawRect(bdRect, accentPaint);

    // ── B → CT connector ────────────────────────────
    final bcPath = Path();
    bcPath.moveTo(ox + 140*s, oy + 40*s);
    bcPath.lineTo(ox + 180*s, oy + 40*s);
    bcPath.lineTo(ox + 180*s, oy + 80*s);
    bcPath.lineTo(ox + 160*s, oy + 80*s);
    bcPath.lineTo(ox + 160*s, oy + 70*s);
    bcPath.lineTo(ox + 140*s, oy + 70*s);
    canvas.drawPath(bcPath, wallPaint);

    // ── CALLOUT LABELS ──────────────────────────────
    _drawLabel(canvas, 'A', ox + 270*s, oy + 55*s, 18 * s,
        AppColors.primary.withValues(alpha: 0.10));
    _drawLabel(canvas, 'B', ox + 70*s, oy + 80*s, 18 * s,
        AppColors.accent.withValues(alpha: 0.08));
    _drawLabel(canvas, 'MID', ox + 182*s, oy + 230*s, 9 * s,
        AppColors.primary.withValues(alpha: 0.06));
    _drawLabel(canvas, 'LONG', ox + 295*s, oy + 210*s, 8 * s,
        AppColors.primary.withValues(alpha: 0.05));
    _drawLabel(canvas, 'T', ox + 188*s, oy + 360*s, 12 * s,
        AppColors.textTertiary.withValues(alpha: 0.06));
    _drawLabel(canvas, 'CT', ox + 188*s, oy + 38*s, 10 * s,
        AppColors.textTertiary.withValues(alpha: 0.06));
    _drawLabel(canvas, 'TUNNELS', ox + 55*s, oy + 300*s, 7 * s,
        AppColors.accent.withValues(alpha: 0.05));
    _drawLabel(canvas, 'CAT', ox + 225*s, oy + 160*s, 7 * s,
        AppColors.primary.withValues(alpha: 0.05));
    _drawLabel(canvas, 'DOORS', ox + 185*s, oy + 188*s, 6 * s,
        AppColors.accent.withValues(alpha: 0.05));
  }

  void _drawLabel(Canvas canvas, String text, double x, double y,
      double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  /// HUD-style corner brackets
  void _drawCornerBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.10)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const m = 20.0; // margin
    const l = 30.0; // bracket length

    // Top-left
    canvas.drawLine(Offset(m, m), Offset(m + l, m), paint);
    canvas.drawLine(Offset(m, m), Offset(m, m + l), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m - l, m), paint);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + l), paint);

    // Bottom-left
    canvas.drawLine(Offset(m, size.height - m), Offset(m + l, size.height - m), paint);
    canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - l), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - m, size.height - m),
        Offset(size.width - m - l, size.height - m), paint);
    canvas.drawLine(Offset(size.width - m, size.height - m),
        Offset(size.width - m, size.height - m - l), paint);
  }

  /// Floating dust/smoke particles
  void _drawFloatingParticles(Canvas canvas, Size size) {
    final rng = Random(13);
    final paint = Paint();

    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      // Subtle vertical drift based on pulse
      final y = baseY + sin(pulseValue * pi + i) * 3;
      final r = rng.nextDouble() * 1.5 + 0.5;
      final alpha = rng.nextDouble() * 0.08 + 0.02;

      paint.color = (i % 3 == 0 ? AppColors.primary : AppColors.accent)
          .withValues(alpha: alpha * pulseValue);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  /// Subtle horizontal scan lines
  void _drawScanLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.015);

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalBgPainter old) =>
      old.radarAngle != radarAngle || old.pulseValue != pulseValue;
}

// ═════════════════════════════════════════════════════════════
// PULSING DOT
// ═════════════════════════════════════════════════════════════

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _StatusDot({required this.color, this.pulse = false});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
        lowerBound: 0.4,
        upperBound: 1.0);
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot old) {
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
      builder: (context, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: widget.pulse
              ? [BoxShadow(
                  color: widget.color.withValues(alpha: _ctrl.value * 0.5),
                  blurRadius: 6, spreadRadius: 1)]
              : null,
        ),
      ),
    );
  }
}
