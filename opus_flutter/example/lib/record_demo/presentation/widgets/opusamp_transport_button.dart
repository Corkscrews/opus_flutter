import 'package:flutter/material.dart';

import '../../app/record_demo_app.dart';
import '../../core/lcd_pixel_font.dart';

enum ButtonIndicator { none, dot, arrow }

class OpusampTransportButton extends StatefulWidget {
  const OpusampTransportButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.activeColor = opusampGreen,
    this.indicator = ButtonIndicator.none,
    this.lockColor = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final Color activeColor;
  final ButtonIndicator indicator;
  /// When true, [activeColor] is used even when the button is disabled,
  /// so callers can control the color independently of the enabled state.
  final bool lockColor;

  @override
  State<OpusampTransportButton> createState() => _OpusampTransportButtonState();
}

class _OpusampTransportButtonState extends State<OpusampTransportButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _onTapDown(TapDownDetails _) {
    if (_enabled) setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (_pressed) {
      setState(() => _pressed = false);
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: CustomPaint(
          painter: _ButtonPainter(
            label: widget.label,
            activeColor: (_enabled || widget.lockColor)
                ? widget.activeColor
                : const Color(0xFF383838),
            pressed: _pressed,
            indicator: widget.indicator,
          ),
          child: const SizedBox(height: 48),
        ),
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  const _ButtonPainter({
    required this.label,
    required this.activeColor,
    required this.pressed,
    this.indicator = ButtonIndicator.none,
  });

  final String label;
  final Color activeColor;
  final bool pressed;
  final ButtonIndicator indicator;

  static const double _gap = 3.0;
  static const double _radius = 2.0;
  static const _blankGlyph = <int>[0, 0, 0, 0, 0, 0, 0];

  @override
  void paint(Canvas canvas, Size size) {
    final faceW = size.width - _gap * 2;
    final faceH = size.height - _gap * 2 - 6; // leave room for shadow below
    final faceTop = pressed ? _gap + 3 : _gap;
    final r = const Radius.circular(_radius);

    final faceRect = Rect.fromLTWH(_gap, faceTop, faceW, faceH);
    final faceRRect = RRect.fromRectAndRadius(faceRect, r);

    // ── Socket — recessed mount in the panel ───────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_gap - 2, _gap - 2, faceW + 4, faceH + 4),
        const Radius.circular(_radius + 2),
      ),
      Paint()..color = const Color(0xFF111111),
    );

    // ── Drop shadow — soft, offset downward ────────────────────────────────
    if (!pressed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          faceRect.translate(0, 5),
          r,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // ── Button face ────────────────────────────────────────────────────────
    // Subtle top-to-bottom gradient: slightly lighter at the top to simulate
    // ambient light catching the face.
    canvas.drawRRect(
      faceRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: pressed
              ? [const Color(0xFF202020), const Color(0xFF252525)]
              : [const Color(0xFF424242), const Color(0xFF333333)],
        ).createShader(faceRect),
    );

    // ── Top highlight — thin bright lip from ambient light ─────────────────
    if (!pressed) {
      canvas.drawLine(
        Offset(_gap + _radius, faceTop + 1),
        Offset(_gap + faceW - _radius, faceTop + 1),
        Paint()
          ..color = const Color(0xFF606060)
          ..strokeWidth = 1.0,
      );
    } else {
      // Pressed: inner top shadow to reinforce the sunken feel
      canvas.drawLine(
        Offset(_gap + _radius, faceTop + 1),
        Offset(_gap + faceW - _radius, faceTop + 1),
        Paint()
          ..color = const Color(0xFF111111)
          ..strokeWidth = 1.5,
      );
    }

    // ── Pixel label ────────────────────────────────────────────────────────
    const cellSize = 1.5;
    const charSlot = (lcdCharWidth + 1) * cellSize;
    final textWidth = label.length * charSlot;
    final textHeight = lcdCharHeight * cellSize;

    const indicatorSize = 6.0;
    const indicatorGap = 4.0;
    final hasIndicator = indicator != ButtonIndicator.none;
    final totalContentWidth =
        hasIndicator ? indicatorSize + indicatorGap + textWidth : textWidth;
    final contentStartX = size.width / 2 - totalContentWidth / 2;

    final textX =
        hasIndicator ? contentStartX + indicatorSize + indicatorGap : contentStartX;
    final textY = faceTop + faceH / 2 - textHeight / 2;

    final litPaint = Paint()..color = activeColor;
    final dimPaint = Paint()..color = activeColor.withValues(alpha: 0.07);

    // ── Indicator ──────────────────────────────────────────────────────────
    switch (indicator) {
      case ButtonIndicator.dot:
        canvas.drawCircle(
          Offset(contentStartX + indicatorSize / 2, faceTop + faceH / 2),
          indicatorSize / 2,
          litPaint,
        );
      case ButtonIndicator.arrow:
        final cx = contentStartX;
        final cy = faceTop + faceH / 2;
        canvas.drawPath(
          Path()
            ..moveTo(cx, cy - indicatorSize / 2)
            ..lineTo(cx + indicatorSize, cy)
            ..lineTo(cx, cy + indicatorSize / 2)
            ..close(),
          litPaint,
        );
      case ButtonIndicator.none:
        break;
    }

    double cursorX = textX;
    for (int i = 0; i < label.length; i++) {
      final glyph = lcdPixelFont[label.codeUnitAt(i)] ?? _blankGlyph;
      for (int row = 0; row < lcdCharHeight; row++) {
        for (int col = 0; col < lcdCharWidth; col++) {
          final isLit = (glyph[row] >> (4 - col)) & 1 == 1;
          canvas.drawRect(
            Rect.fromLTWH(
              cursorX + col * cellSize,
              textY + row * cellSize,
              cellSize,
              cellSize,
            ),
            isLit ? litPaint : dimPaint,
          );
        }
      }
      cursorX += charSlot;
    }
  }

  @override
  bool shouldRepaint(covariant _ButtonPainter old) =>
      label != old.label ||
      activeColor != old.activeColor ||
      pressed != old.pressed ||
      indicator != old.indicator;
}
