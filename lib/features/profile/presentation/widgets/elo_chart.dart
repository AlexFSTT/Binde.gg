import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// ELO rating history chart — fetches from elo_history table.
/// Uses CustomPainter for a clean line chart.
class EloChart extends StatefulWidget {
  final String playerId;
  const EloChart({super.key, required this.playerId});

  @override
  State<EloChart> createState() => _EloChartState();
}

class _EloChartState extends State<EloChart> {
  List<_EloPoint>? _points;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEloHistory();
  }

  Future<void> _loadEloHistory() async {
    try {
      final data = await SupabaseConfig.client
          .from('elo_history')
          .select('elo_after, created_at')
          .eq('player_id', widget.playerId)
          .order('created_at', ascending: true)
          .limit(50);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _points = data
            .map((row) => _EloPoint(
                  elo: row['elo_after'] as int,
                  date: DateTime.parse(row['created_at'] as String),
                ))
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                const Icon(Icons.show_chart_rounded,
                    size: 18, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(
                  'ELO History',
                  style: AppTextStyles.label.copyWith(fontSize: 14),
                ),
                const Spacer(),
                if (_points != null && _points!.isNotEmpty)
                  Text(
                    '${_points!.length} matches',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Chart area
          SizedBox(
            height: 200,
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                : (_points == null || _points!.isEmpty)
                    ? Center(
                        child: Text(
                          'No ELO history yet',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textTertiary),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _EloChartPainter(points: _points!),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EloPoint {
  final int elo;
  final DateTime date;
  const _EloPoint({required this.elo, required this.date});
}

class _EloChartPainter extends CustomPainter {
  final List<_EloPoint> points;
  _EloChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final minElo = points.map((p) => p.elo).reduce(min) - 20;
    final maxElo = points.map((p) => p.elo).reduce(max) + 20;
    final eloRange = (maxElo - minElo).clamp(1, double.infinity);

    // Grid lines
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      // Grid label
      final elo = maxElo - (eloRange * i / 3).round();
      final tp = TextPainter(
        text: TextSpan(
          text: '$elo',
          style: TextStyle(
            color: AppColors.textTertiary.withValues(alpha: 0.6),
            fontSize: 10,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - 12));
    }

    // Build path
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * i / (points.length - 1);
      final y = size.height -
          ((points[i].elo - minElo) / eloRange * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        // Smooth curve
        final prevX = size.width * (i - 1) / (points.length - 1);
        final prevY = size.height -
            ((points[i - 1].elo - minElo) / eloRange * size.height);
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    // Fill gradient
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final lastElo = points.last.elo;
    final firstElo = points.first.elo;
    final isUp = lastElo >= firstElo;
    final lineColor = isUp ? AppColors.success : AppColors.danger;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.15),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Current point dot
    if (points.isNotEmpty) {
      final lastX = points.length == 1
          ? size.width / 2
          : size.width;
      final lastY = size.height -
          ((points.last.elo - minElo) / eloRange * size.height);

      canvas.drawCircle(
        Offset(lastX, lastY),
        5,
        Paint()..color = lineColor,
      );
      canvas.drawCircle(
        Offset(lastX, lastY),
        3,
        Paint()..color = AppColors.bgSurface,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EloChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
