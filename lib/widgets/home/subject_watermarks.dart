import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Faint subject-themed watermark graphics for home subject cards.
class SubjectWatermark extends StatelessWidget {
  const SubjectWatermark({
    super.key,
    required this.subjectName,
    required this.color,
  });

  final String subjectName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(130, 130),
      painter: _WatermarkPainter(
        subjectName: subjectName,
        color: color.withValues(alpha: 0.12),
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter({required this.subjectName, required this.color});

  final String subjectName;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;

    switch (subjectName) {
      case 'Biology':
        _paintDna(canvas, size, paint);
      case 'Chemistry':
        _paintMolecule(canvas, size, paint);
      case 'Physics':
        _paintWave(canvas, size, paint);
      case 'Geography':
        _paintGlobe(canvas, size, paint);
      case 'History':
        _paintTemple(canvas, size, paint);
      case 'Economics':
        _paintChart(canvas, size, paint);
      case 'Mathematics':
        _paintMath(canvas, size, paint);
      case 'English':
        _paintBook(canvas, size, paint);
      default:
        break;
    }
  }

  void _paintDna(Canvas canvas, Size size, Paint paint) {
    final cx = size.width * 0.55;
    final pathL = Path();
    final pathR = Path();
    for (var i = 0; i <= 18; i++) {
      final t = i / 18;
      final y = size.height * 0.08 + t * size.height * 0.84;
      final wave = math.sin(t * math.pi * 4) * size.width * 0.16;
      final x1 = cx - wave;
      final x2 = cx + wave;
      if (i == 0) {
        pathL.moveTo(x1, y);
        pathR.moveTo(x2, y);
      } else {
        pathL.lineTo(x1, y);
        pathR.lineTo(x2, y);
      }
      if (i % 2 == 0) {
        canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
      }
    }
    canvas.drawPath(pathL, paint);
    canvas.drawPath(pathR, paint);
  }

  void _paintMolecule(Canvas canvas, Size size, Paint paint) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final nodes = [
      Offset(size.width * 0.35, size.height * 0.35),
      Offset(size.width * 0.62, size.height * 0.28),
      Offset(size.width * 0.72, size.height * 0.55),
      Offset(size.width * 0.48, size.height * 0.68),
      Offset(size.width * 0.28, size.height * 0.58),
    ];
    for (var i = 0; i < nodes.length; i++) {
      canvas.drawLine(nodes[i], nodes[(i + 1) % nodes.length], paint);
    }
    canvas.drawLine(nodes[0], nodes[2], paint);
    for (final n in nodes) {
      canvas.drawCircle(n, 4.5, fill);
    }
  }

  void _paintWave(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    path.moveTo(size.width * 0.08, size.height * 0.55);
    for (var i = 0; i <= 40; i++) {
      final t = i / 40;
      final x = size.width * 0.08 + t * size.width * 0.84;
      final y = size.height * 0.55 +
          math.sin(t * math.pi * 3) * size.height * 0.18;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint..strokeWidth = 2);
  }

  void _paintGlobe(Canvas canvas, Size size, Paint paint) {
    final c = Offset(size.width * 0.55, size.height * 0.52);
    final r = size.width * 0.32;
    canvas.drawCircle(c, r, paint);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 0.7, height: r * 2),
      paint,
    );
    canvas.drawLine(
      Offset(c.dx - r, c.dy),
      Offset(c.dx + r, c.dy),
      paint,
    );
    canvas.drawLine(
      Offset(c.dx - r * 0.85, c.dy - r * 0.45),
      Offset(c.dx + r * 0.85, c.dy - r * 0.45),
      paint,
    );
    canvas.drawLine(
      Offset(c.dx - r * 0.85, c.dy + r * 0.45),
      Offset(c.dx + r * 0.85, c.dy + r * 0.45),
      paint,
    );
  }

  void _paintTemple(Canvas canvas, Size size, Paint paint) {
    final baseY = size.height * 0.78;
    final topY = size.height * 0.32;
    final left = size.width * 0.28;
    final right = size.width * 0.78;
    // roof
    final roof = Path()
      ..moveTo((left + right) / 2, size.height * 0.18)
      ..lineTo(left - 4, topY)
      ..lineTo(right + 4, topY)
      ..close();
    canvas.drawPath(roof, paint);
    canvas.drawLine(Offset(left, topY), Offset(right, topY), paint);
    // columns
    for (final x in [0.34, 0.46, 0.58, 0.70]) {
      final cx = size.width * x;
      canvas.drawLine(Offset(cx, topY), Offset(cx, baseY), paint..strokeWidth = 2.2);
    }
    canvas.drawLine(Offset(left, baseY), Offset(right, baseY), paint);
    canvas.drawLine(
      Offset(left - 6, baseY + 6),
      Offset(right + 6, baseY + 6),
      paint,
    );
  }

  void _paintChart(Canvas canvas, Size size, Paint paint) {
    final base = size.height * 0.75;
    final bars = [0.28, 0.42, 0.55, 0.38];
    for (var i = 0; i < bars.length; i++) {
      final x = size.width * (0.28 + i * 0.14);
      final h = size.height * bars[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, base - h, 10, h),
          const Radius.circular(2),
        ),
        paint..style = PaintingStyle.fill,
      );
    }
    paint.style = PaintingStyle.stroke;
    final line = Path()
      ..moveTo(size.width * 0.28, size.height * 0.55)
      ..lineTo(size.width * 0.42, size.height * 0.42)
      ..lineTo(size.width * 0.56, size.height * 0.30)
      ..lineTo(size.width * 0.72, size.height * 0.22);
    canvas.drawPath(line, paint..strokeWidth = 2);
  }

  void _paintMath(Canvas canvas, Size size, Paint paint) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'π  ∑\nx²',
        style: TextStyle(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.28, size.height * 0.28));
  }

  void _paintBook(Canvas canvas, Size size, Paint paint) {
    final cx = size.width * 0.55;
    final top = size.height * 0.28;
    final bottom = size.height * 0.78;
    final path = Path()
      ..moveTo(cx, top + 8)
      ..quadraticBezierTo(cx - 40, top, cx - 38, bottom)
      ..quadraticBezierTo(cx, bottom - 10, cx, bottom - 10)
      ..quadraticBezierTo(cx, bottom - 10, cx + 38, bottom)
      ..quadraticBezierTo(cx + 40, top, cx, top + 8);
    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(cx, top + 8), Offset(cx, bottom - 10), paint);
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) {
    return oldDelegate.subjectName != subjectName || oldDelegate.color != color;
  }
}
