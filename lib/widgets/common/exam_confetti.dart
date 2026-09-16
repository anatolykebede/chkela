import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Polished falling confetti for passing scores.
class ExamConfettiCelebration extends StatefulWidget {
  const ExamConfettiCelebration({super.key});

  @override
  State<ExamConfettiCelebration> createState() =>
      _ExamConfettiCelebrationState();
}

enum _ConfettiShape { rect, circle, ribbon, star, streamer }

class _ConfettiPiece {
  _ConfettiPiece({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.width,
    required this.height,
    required this.primary,
    required this.secondary,
    required this.rotation,
    required this.spin,
    required this.shape,
    required this.wobble,
    required this.wobbleSpeed,
    required this.spawnDelay,
    required this.depth,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double width;
  final double height;
  final Color primary;
  final Color secondary;
  double rotation;
  final double spin;
  final _ConfettiShape shape;
  final double wobble;
  final double wobbleSpeed;
  final double spawnDelay;
  final double depth;
  double _wobblePhase = 0;
}

class _ExamConfettiCelebrationState extends State<ExamConfettiCelebration>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 4500);
  static const _gravity = 380.0;

  final _rng = math.Random();
  final List<_ConfettiPiece> _pieces = [];
  AnimationController? _controller;
  Duration _lastPhysicsTick = Duration.zero;
  bool _firedHaptic = false;
  bool _finished = false;

  static const _pairs = [
    (AppColors.accent, Color(0xFFB8AEFF)),
    (AppColors.accentText, AppColors.accent),
    (AppColors.teal, Color(0xFF7DFFF0)),
    (AppColors.gold, Color(0xFFFFF3B0)),
    (AppColors.battleCoral, Color(0xFFFF9A7A)),
    (AppColors.info, Color(0xFF7EC8FF)),
    (Colors.white, Color(0xFFE8ECFF)),
    (Color(0xFFFF6FD8), Color(0xFFFFB86C)),
  ];

  @override
  void initState() {
    super.initState();
    _spawnCelebration();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addListener(_onTick)
      ..forward().whenComplete(_onComplete);
  }

  void _onComplete() {
    if (!mounted) return;
    _controller?.dispose();
    _controller = null;
    setState(() {
      _finished = true;
      _pieces.clear();
    });
  }

  void _spawnCelebration() {
    _spawnRain(count: 56, delay: 0);
    _spawnRain(count: 20, delay: 0.35);
    _spawnCannon(fromLeft: true, count: 26, delay: 0.06);
    _spawnCannon(fromLeft: false, count: 26, delay: 0.1);
    _spawnCenterBurst(count: 34, delay: 0.04);
    _spawnSparkles(count: 24, delay: 0.15);
  }

  (Color, Color) _randomColors() => _pairs[_rng.nextInt(_pairs.length)];

  _ConfettiShape _randomShape() {
    final roll = _rng.nextDouble();
    if (roll < 0.3) return _ConfettiShape.ribbon;
    if (roll < 0.5) return _ConfettiShape.rect;
    if (roll < 0.64) return _ConfettiShape.streamer;
    if (roll < 0.8) return _ConfettiShape.star;
    return _ConfettiShape.circle;
  }

  double _sizeFor(_ConfettiShape shape) {
    return switch (shape) {
      _ConfettiShape.ribbon => 9 + _rng.nextDouble() * 6,
      _ConfettiShape.rect => 8 + _rng.nextDouble() * 8,
      _ConfettiShape.streamer => 7 + _rng.nextDouble() * 5,
      _ConfettiShape.star => 10 + _rng.nextDouble() * 8,
      _ConfettiShape.circle => 7 + _rng.nextDouble() * 7,
    };
  }

  double _heightFor(_ConfettiShape shape, double width) {
    return switch (shape) {
      _ConfettiShape.ribbon => width * (2.2 + _rng.nextDouble()),
      _ConfettiShape.streamer => width * (3.2 + _rng.nextDouble() * 1.4),
      _ConfettiShape.star => width,
      _ConfettiShape.circle => width,
      _ConfettiShape.rect => width * (0.5 + _rng.nextDouble() * 0.45),
    };
  }

  _ConfettiPiece _makePiece({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double spawnDelay,
    double depthScale = 1,
  }) {
    final shape = _randomShape();
    final width = _sizeFor(shape) * depthScale;
    final colors = _randomColors();

    return _ConfettiPiece(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      width: width,
      height: _heightFor(shape, width),
      primary: colors.$1,
      secondary: colors.$2,
      rotation: _rng.nextDouble() * math.pi * 2,
      spin: (_rng.nextDouble() - 0.5) * 9,
      shape: shape,
      wobble: 0.012 + _rng.nextDouble() * 0.018,
      wobbleSpeed: 4 + _rng.nextDouble() * 4,
      spawnDelay: spawnDelay,
      depth: depthScale.clamp(0.6, 1.1),
    );
  }

  void _spawnRain({required int count, required double delay}) {
    for (var i = 0; i < count; i++) {
      _pieces.add(
        _makePiece(
          x: _rng.nextDouble(),
          y: -0.08 - _rng.nextDouble() * 0.3,
          vx: (_rng.nextDouble() - 0.5) * 0.38,
          vy: 0.2 + _rng.nextDouble() * 0.32,
          spawnDelay: delay + _rng.nextDouble() * 0.3,
          depthScale: 0.75 + _rng.nextDouble() * 0.35,
        ),
      );
    }
  }

  void _spawnCannon({
    required bool fromLeft,
    required int count,
    required double delay,
  }) {
    for (var i = 0; i < count; i++) {
      _pieces.add(
        _makePiece(
          x: fromLeft ? -0.04 : 1.04,
          y: 0.1 + _rng.nextDouble() * 0.45,
          vx: fromLeft
              ? 0.52 + _rng.nextDouble() * 0.4
              : -(0.52 + _rng.nextDouble() * 0.4),
          vy: -(0.38 + _rng.nextDouble() * 0.5),
          spawnDelay: delay + _rng.nextDouble() * 0.1,
          depthScale: 0.9 + _rng.nextDouble() * 0.25,
        ),
      );
    }
  }

  void _spawnCenterBurst({required int count, required double delay}) {
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final power = 0.42 + _rng.nextDouble() * 0.65;
      _pieces.add(
        _makePiece(
          x: 0.4 + _rng.nextDouble() * 0.2,
          y: 0.12 + _rng.nextDouble() * 0.1,
          vx: math.cos(angle) * power,
          vy: math.sin(angle) * power - 0.58,
          spawnDelay: delay + _rng.nextDouble() * 0.06,
          depthScale: 1.0 + _rng.nextDouble() * 0.2,
        ),
      );
    }
  }

  void _spawnSparkles({required int count, required double delay}) {
    for (var i = 0; i < count; i++) {
      final colors = _randomColors();
      _pieces.add(
        _ConfettiPiece(
          x: 0.2 + _rng.nextDouble() * 0.6,
          y: 0.04 + _rng.nextDouble() * 0.3,
          vx: (_rng.nextDouble() - 0.5) * 0.2,
          vy: 0.1 + _rng.nextDouble() * 0.24,
          width: 3 + _rng.nextDouble() * 3,
          height: 3 + _rng.nextDouble() * 3,
          primary: Colors.white,
          secondary: colors.$1,
          rotation: 0,
          spin: 0,
          shape: _ConfettiShape.circle,
          wobble: 0.008,
          wobbleSpeed: 7 + _rng.nextDouble() * 5,
          spawnDelay: delay + _rng.nextDouble() * 0.35,
          depth: 1.15,
        ),
      );
    }
  }

  void _onTick() {
    if (_finished || _controller == null) return;

    final elapsed = _controller!.lastElapsedDuration ?? Duration.zero;
    final t = elapsed.inMicroseconds / 1000000.0;

    if (!_firedHaptic && t > 0.02) {
      _firedHaptic = true;
      HapticFeedback.mediumImpact();
    }

    var dt = (elapsed - _lastPhysicsTick).inMicroseconds / 1000000.0;
    _lastPhysicsTick = elapsed;
    if (dt <= 0) {
      if (mounted) setState(() {});
      return;
    }
    dt = dt.clamp(0.0, 0.032);

    for (final piece in _pieces) {
      if (t < piece.spawnDelay) continue;

      piece.vy += _gravity * dt * 0.001;
      piece._wobblePhase += piece.wobbleSpeed * dt;
      final flutter = math.sin(piece._wobblePhase) * piece.wobble;
      piece.x += (piece.vx + flutter) * dt;
      piece.y += piece.vy * dt;
      piece.rotation += piece.spin * dt;
      piece.vx *= 0.992;
    }

    if (mounted) setState(() {});
  }

  double get _globalOpacity {
    if (_finished || _controller == null) return 0;
    final t = _controller!.value;
    if (t < 0.05) return Curves.easeOut.transform(t / 0.05);
    if (t > 0.78) return ((1 - t) / 0.22).clamp(0.0, 1.0);
    return 1;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null ||
        _finished ||
        _pieces.isEmpty ||
        _globalOpacity <= 0) {
      return const SizedBox.shrink();
    }

    final t = (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds /
        1000000.0;

    return IgnorePointer(
      child: Opacity(
        opacity: _globalOpacity,
        child: CustomPaint(
          painter: _ConfettiPainter(
            pieces: _pieces,
            time: t,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.pieces,
    required this.time,
  });

  final List<_ConfettiPiece> pieces;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      if (time < piece.spawnDelay) continue;

      final age = time - piece.spawnDelay;
      final px = piece.x * size.width;
      final py = piece.y * size.height;
      if (py > size.height + 56 || px < -56 || px > size.width + 56) continue;

      final enter = Curves.easeOutCubic.transform((age / 0.2).clamp(0.0, 1.0));
      final depthFade = 0.6 + piece.depth * 0.35;
      final twinkle = 0.88 + math.sin(piece._wobblePhase * 1.3) * 0.12;
      final fallFade = (1.08 - piece.y).clamp(0.4, 1.0);
      final opacity =
          (enter * depthFade * twinkle * fallFade).clamp(0.0, 1.0);
      if (opacity < 0.03) continue;

      final scale = 0.7 + enter * 0.3;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(piece.rotation);
      canvas.scale(scale);
      _drawPiece(canvas, piece, opacity);
      canvas.restore();
    }
  }

  void _drawPiece(Canvas canvas, _ConfettiPiece piece, double opacity) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: piece.width,
      height: piece.height,
    );

    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          piece.primary.withValues(alpha: opacity),
          piece.secondary.withValues(alpha: opacity * 0.9),
        ],
      ).createShader(rect);

    switch (piece.shape) {
      case _ConfettiShape.circle:
        _drawGlowingCircle(canvas, piece.width * 0.5, gradient, opacity);
      case _ConfettiShape.rect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(piece.width * 0.2),
          ),
          gradient,
        );
        _drawHighlight(canvas, rect, opacity);
      case _ConfettiShape.ribbon:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(piece.width * 0.4),
          ),
          gradient,
        );
        _drawHighlight(canvas, rect.deflate(1.2), opacity * 0.65);
      case _ConfettiShape.streamer:
        final path = Path()
          ..moveTo(-piece.width * 0.42, -piece.height * 0.5)
          ..quadraticBezierTo(
            piece.width * 0.5,
            -piece.height * 0.08,
            -piece.width * 0.3,
            piece.height * 0.5,
          )
          ..quadraticBezierTo(
            -piece.width * 0.62,
            piece.height * 0.06,
            -piece.width * 0.42,
            -piece.height * 0.5,
          );
        canvas.drawPath(path, gradient);
      case _ConfettiShape.star:
        _drawStar(canvas, piece.width * 0.52, gradient, opacity);
    }
  }

  void _drawGlowingCircle(
    Canvas canvas,
    double radius,
    Paint fill,
    double opacity,
  ) {
    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.2 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset.zero, radius + 1.2, glow);
    canvas.drawCircle(Offset.zero, radius, fill);
  }

  void _drawHighlight(Canvas canvas, Rect rect, double opacity) {
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.3 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1.4), const Radius.circular(2)),
      highlight,
    );
  }

  void _drawStar(Canvas canvas, double radius, Paint fill, double opacity) {
    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.16 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset.zero, radius + 1, glow);

    final path = Path();
    for (var i = 0; i < 5; i++) {
      final outerAngle = -math.pi / 2 + i * 4 * math.pi / 5;
      final innerAngle = outerAngle + 2 * math.pi / 10;
      final outer = Offset(
        math.cos(outerAngle) * radius,
        math.sin(outerAngle) * radius,
      );
      final inner = Offset(
        math.cos(innerAngle) * radius * 0.42,
        math.sin(innerAngle) * radius * 0.42,
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.time != time;
}
