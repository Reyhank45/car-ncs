import 'dart:math';
import 'package:flutter/material.dart';

class NcsLogo extends StatelessWidget {
  final double size;
  final Color? glowColor;

  const NcsLogo({
    super.key,
    this.size = 28,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NcsLogoPainter(glowColor: glowColor ?? const Color(0xFF00FF88)),
      ),
    );
  }
}

class _NcsLogoPainter extends CustomPainter {
  final Color glowColor;

  _NcsLogoPainter({required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer glow
    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, radius - 2, glowPaint);

    // Outer circle
    final circlePaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 2, circlePaint);

    // Inner stylized segmented sound ring
    final tickPaint = Paint()
      ..color = glowColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4) + (pi / 8);
      final p1 = Offset(
        center.dx + (radius - 7) * cos(angle),
        center.dy + (radius - 7) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 4) * cos(angle),
        center.dy + (radius - 4) * sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Inner filled core
    final corePaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.28, corePaint);
  }

  @override
  bool shouldRepaint(covariant _NcsLogoPainter oldDelegate) =>
      oldDelegate.glowColor != glowColor;
}

