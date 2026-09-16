import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';

/// Animated highlight that travels around a card border.
class TravelingBorderHighlight extends StatefulWidget {
  const TravelingBorderHighlight({
    super.key,
    required this.child,
    this.accent = AppColors.accent,
    this.radius = HomeLayout.cardRadius,
    this.trackColor = AppColors.border,
    this.duration = const Duration(milliseconds: 2400),
    this.onTap,
  });

  final Widget child;
  final Color accent;
  final double radius;
  final Color trackColor;
  final Duration duration;
  final VoidCallback? onTap;

  @override
  State<TravelingBorderHighlight> createState() =>
      _TravelingBorderHighlightState();
}

class _TravelingBorderHighlightState extends State<TravelingBorderHighlight> {
  static const _tick = Duration(milliseconds: 32);

  Timer? _timer;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant TravelingBorderHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    final step = _tick.inMilliseconds / widget.duration.inMilliseconds;
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      setState(() => _progress = (_progress + step) % 1.0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      painter: TravelingBorderPainter(
        progress: _progress,
        radius: widget.radius,
        accent: widget.accent,
        trackColor: widget.trackColor,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return painted;
    return GestureDetector(onTap: widget.onTap, child: painted);
  }
}

class TravelingBorderPainter extends CustomPainter {
  TravelingBorderPainter({
    required this.progress,
    required this.radius,
    required this.accent,
    required this.trackColor,
  });

  final double progress;
  final double radius;
  final Color accent;
  final Color trackColor;

  static const _stroke = 1.5;
  static const _segment = 0.24;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = _stroke / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - _stroke,
        size.height - _stroke,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = trackColor;
    canvas.drawPath(path, track);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke + 1.5
      ..color = accent.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = accent;

    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      final segLen = length * _segment;
      final start = length * progress;
      final end = start + segLen;

      if (end <= length) {
        final segment = metric.extractPath(start, end);
        canvas.drawPath(segment, glow);
        canvas.drawPath(segment, highlight);
      } else {
        final first = metric.extractPath(start, length);
        final second = metric.extractPath(0, end - length);
        canvas.drawPath(first, glow);
        canvas.drawPath(first, highlight);
        canvas.drawPath(second, glow);
        canvas.drawPath(second, highlight);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TravelingBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.trackColor != trackColor;
  }
}
