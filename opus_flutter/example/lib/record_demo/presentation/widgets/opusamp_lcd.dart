import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:opus_dart/opus_dart.dart';

import '../../app/record_demo_app.dart';
import '../../core/audio_constants.dart';
import '../../core/lcd_pixel_font.dart';
import '../../core/recorder_phase.dart';
import 'opusamp_lcd_surface.dart';

class OpusampLcd extends StatefulWidget {
  const OpusampLcd({
    super.key,
    required this.phase,
    required this.statusText,
  });

  final RecorderPhase phase;
  final String statusText;

  @override
  State<OpusampLcd> createState() => _OpusampLcdState();
}

class _OpusampLcdState extends State<OpusampLcd>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll;
  late final String _infoText;

  final _flicker = ValueNotifier<double>(0.0);
  final _rng = Random();
  Timer? _flickerTimer;

  static const double _scrollGap = 48.0;
  static const double _scrollSpeed = 18.0;
  static const double _infoCharSlot =
      (lcdCharWidth + 1) * _LcdPixelPainter.infoCellSize;

  @override
  void initState() {
    super.initState();
    _infoText = 'OPUS | ${getOpusVersion()} | ${demoSampleRate}HZ | MONO';
    final cycleWidth = _infoText.length * _infoCharSlot + _scrollGap;
    _scroll = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (cycleWidth / _scrollSpeed * 1000).round(),
      ),
    )..repeat();

    _scheduleNextFlicker();
  }

  void _scheduleNextFlicker() {
    // Wait a random quiet interval (1–6 s) before the next flicker event.
    final quietMs = 1000 + _rng.nextInt(5000);
    _flickerTimer = Timer(Duration(milliseconds: quietMs), _runFlickerEvent);
  }

  Future<void> _runFlickerEvent() async {
    // A flicker event is 1–4 rapid on/off pulses.
    final pulses = 1 + _rng.nextInt(3);
    for (int i = 0; i < pulses; i++) {
      // Drop brightness by 20–70 %.
      _flicker.value = 0.20 + _rng.nextDouble() * 0.50;
      await Future.delayed(
        Duration(milliseconds: 30 + _rng.nextInt(80)),
      );
      _flicker.value = 0.0;
      if (i < pulses - 1) {
        await Future.delayed(
          Duration(milliseconds: 20 + _rng.nextInt(60)),
        );
      }
    }
    _scheduleNextFlicker();
  }

  @override
  void dispose() {
    _flickerTimer?.cancel();
    _flicker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (widget.phase) {
      RecorderPhase.recording => opusampRed,
      RecorderPhase.idle when widget.statusText == 'Idle' => opusampGreen,
      RecorderPhase.idle => opusampAmber,
      _ => opusampAmber,
    };

    return OpusampLcdSurface(
      child: SizedBox(
        height: _LcdPixelPainter.totalHeight,
        child: CustomPaint(
          painter: _LcdPixelPainter(
            statusText: widget.statusText.toUpperCase(),
            statusColor: statusColor,
            infoText: _infoText,
            infoColor: opusampGreenDim,
            infoScroll: _scroll,
            flicker: _flicker,
          ),
        ),
      ),
    );
  }
}

class _LcdPixelPainter extends CustomPainter {
  _LcdPixelPainter({
    required this.statusText,
    required this.statusColor,
    required this.infoText,
    required this.infoColor,
    required Animation<double> infoScroll,
    required ValueNotifier<double> flicker,
  })  : _infoScroll = infoScroll,
        _flicker = flicker,
        super(repaint: Listenable.merge([infoScroll, flicker]));

  final String statusText;
  final Color statusColor;
  final String infoText;
  final Color infoColor;
  final Animation<double> _infoScroll;
  final ValueNotifier<double> _flicker;

  static const double _cellSize = 2.0;
  static const double _infoCellSize = 1.5;
  static const double _gapWidth = 0.5;
  static const double _padding = 16.0;
  static const double _lineGap = 6.0;
  static const int _charSpacing = 1;
  static const double _scrollGap = 48.0;
  static const double _charSlot = (lcdCharWidth + _charSpacing) * _cellSize;
  static const double _infoCharSlot =
      (lcdCharWidth + _charSpacing) * _infoCellSize;
  static const _blankGlyph = [0, 0, 0, 0, 0, 0, 0];
  static const double infoCellSize = _infoCellSize;
  static const double totalHeight = _padding +
      (lcdCharHeight * _cellSize) +
      _lineGap +
      (lcdCharHeight * _infoCellSize) +
      _padding;

  @override
  void paint(Canvas canvas, Size size) {
    final statusY = _padding;
    final infoY = _padding + (lcdCharHeight * _cellSize) + _lineGap;

    final flicker = _flicker.value;

    _drawText(canvas, statusText, _padding, statusY, statusColor, flicker,
        _cellSize, _charSlot);

    final textWidth = infoText.length * _infoCharSlot;
    final totalCycle = textWidth + _scrollGap;
    final rawOffset = _infoScroll.value * totalCycle;
    final pixelOffset = (rawOffset / _infoCellSize).floor() * _infoCellSize;

    _drawText(canvas, infoText, -pixelOffset, infoY, infoColor, flicker,
        _infoCellSize, _infoCharSlot);
    _drawText(canvas, infoText, -pixelOffset + totalCycle, infoY, infoColor,
        flicker, _infoCellSize, _infoCharSlot);

    final gapPaint = Paint()..color = const Color(0x28000000);
    final innerSize = _cellSize - _gapWidth;
    for (double y = 0; y <= size.height - _gapWidth; y += _cellSize) {
      canvas.drawRect(
        Rect.fromLTWH(0, y + innerSize, size.width, _gapWidth),
        gapPaint,
      );
    }
    for (double x = 0; x <= size.width - _gapWidth; x += _cellSize) {
      canvas.drawRect(
        Rect.fromLTWH(x + innerSize, 0, _gapWidth, size.height),
        gapPaint,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color,
    double flicker,
    double cellSize,
    double charSlot,
  ) {
    final litPaint = Paint()..color = color.withValues(alpha: 1.0 - flicker);
    final dimPaint = Paint()
      ..color = color.withValues(alpha: 0.04 * (1.0 - flicker));

    double cursorX = x;
    for (int i = 0; i < text.length; i++) {
      final glyph = lcdPixelFont[text.codeUnitAt(i)] ?? _blankGlyph;
      for (int row = 0; row < lcdCharHeight; row++) {
        for (int col = 0; col < lcdCharWidth; col++) {
          final isLit = (glyph[row] >> (4 - col)) & 1 == 1;
          canvas.drawRect(
            Rect.fromLTWH(
              cursorX + col * cellSize,
              y + row * cellSize,
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
  bool shouldRepaint(covariant _LcdPixelPainter oldDelegate) =>
      statusText != oldDelegate.statusText ||
      statusColor != oldDelegate.statusColor ||
      infoText != oldDelegate.infoText ||
      infoColor != oldDelegate.infoColor;
}
