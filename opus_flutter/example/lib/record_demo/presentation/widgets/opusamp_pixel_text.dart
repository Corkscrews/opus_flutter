import 'package:flutter/material.dart';

import '../../core/lcd_pixel_font.dart';

/// Renders a string using the 5×7 LCD bitmap font as individual pixel cells.
///
/// [cellSize] controls the size of each pixel cell (2.0 for the main status
/// line, 1.5 for the smaller info line). The widget sizes itself to exactly
/// fit the rendered text.
class OpusampPixelText extends StatelessWidget {
  const OpusampPixelText(
    this.text, {
    super.key,
    required this.color,
    this.cellSize = 2.0,
  });

  final String text;
  final Color color;
  final double cellSize;

  static const int _charSpacing = 1;

  double get _charSlot => (lcdCharWidth + _charSpacing) * cellSize;
  double get _pixelWidth => text.length * _charSlot;
  double get _pixelHeight => lcdCharHeight * cellSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(_pixelWidth, _pixelHeight),
      painter: _PixelTextPainter(
        text: text,
        color: color,
        cellSize: cellSize,
      ),
    );
  }
}

class _PixelTextPainter extends CustomPainter {
  const _PixelTextPainter({
    required this.text,
    required this.color,
    required this.cellSize,
  });

  final String text;
  final Color color;
  final double cellSize;

  static const int _charSpacing = 1;
  static const _blankGlyph = <int>[0, 0, 0, 0, 0, 0, 0];

  @override
  void paint(Canvas canvas, Size size) {
    final litPaint = Paint()..color = color;
    final dimPaint = Paint()..color = color.withValues(alpha: 0.04);
    final charSlot = (lcdCharWidth + _charSpacing) * cellSize;

    double cursorX = 0;
    for (int i = 0; i < text.length; i++) {
      final glyph = lcdPixelFont[text.codeUnitAt(i)] ?? _blankGlyph;
      for (int row = 0; row < lcdCharHeight; row++) {
        for (int col = 0; col < lcdCharWidth; col++) {
          final isLit = (glyph[row] >> (4 - col)) & 1 == 1;
          canvas.drawRect(
            Rect.fromLTWH(
              cursorX + col * cellSize,
              row * cellSize,
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
  bool shouldRepaint(covariant _PixelTextPainter old) =>
      text != old.text || color != old.color || cellSize != old.cellSize;
}
