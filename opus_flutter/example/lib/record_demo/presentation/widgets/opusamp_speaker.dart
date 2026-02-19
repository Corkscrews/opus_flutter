import 'dart:math';

import 'package:flutter/material.dart';

import 'opusamp_lcd_surface.dart';

/// A decorative vintage speaker grille widget.
///
/// Renders a punched-dot grille pattern using [CustomPainter] — each dot has
/// a dark "hole" with a subtle bottom-right highlight to give depth, matching
/// the LCD surface aesthetic.
class OpusampSpeaker extends StatelessWidget {
  const OpusampSpeaker({super.key});

  @override
  Widget build(BuildContext context) {
    return OpusampLcdSurface(
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(painter: const _SpeakerGrillePainter()),
      ),
    );
  }
}

class _SpeakerGrillePainter extends CustomPainter {
  const _SpeakerGrillePainter();

  static const double _spacing = 5.0;
  static const double _dotRadius = 1.4;
  static const double _padding = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final holePaint = Paint()..color = const Color(0xFF000000);
    final rimPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final highlightPaint = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final cols = ((size.width - _padding * 2) / _spacing).floor();
    final rows = ((size.height - _padding * 2) / _spacing).floor();
    final xStart = (size.width - (cols - 1) * _spacing) / 2;
    final yStart = (size.height - (rows - 1) * _spacing) / 2;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = xStart + col * _spacing;
        final cy = yStart + row * _spacing;
        final center = Offset(cx, cy);

        // Punched hole
        canvas.drawCircle(center, _dotRadius, holePaint);

        // Dark rim (top-left) — shadow side
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: _dotRadius + 0.5),
          pi * 0.75,
          pi,
          false,
          rimPaint,
        );

        // Light rim (bottom-right) — highlight side
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: _dotRadius + 0.5),
          pi * 1.75,
          pi,
          false,
          highlightPaint,
        );
      }
    }

    // Subtle radial vignette to give the grille a slight dome/convex look.
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
          ],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _SpeakerGrillePainter old) => false;
}
