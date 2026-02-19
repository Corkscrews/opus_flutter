import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

import '../../app/record_demo_app.dart';
import 'opusamp_lcd_surface.dart';
import 'opusamp_pixel_text.dart';

class OpusampFileInfo extends StatelessWidget {
  const OpusampFileInfo({
    super.key,
    required this.opusFile,
    required this.wavFile,
  });

  final File? opusFile;
  final File? wavFile;

  static const double _cellSize = 1.5;

  @override
  Widget build(BuildContext context) {
    return OpusampLcdSurface(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PixelInfoRow(
              label: 'OPUS',
              value: opusFile?.path,
              cellSize: _cellSize,
            ),
            const SizedBox(height: 4),
            _PixelInfoRow(
              label: 'WAV ',
              value: wavFile?.path,
              cellSize: _cellSize,
            ),
          ],
        ),
      ),
    );
  }
}

class _PixelInfoRow extends StatelessWidget {
  const _PixelInfoRow({
    required this.label,
    required this.value,
    required this.cellSize,
  });

  final String label;
  final String? value;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final displayValue = hasValue
        ? value!.toUpperCase()
        : '---';
    final valueColor = hasValue ? opusampGreenDim : const Color(0xFF2A2A2A);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OpusampPixelText(
          '${label.toUpperCase()}: ',
          color: opusampGreenDim,
          cellSize: cellSize,
        ),
        Expanded(
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: OpusampPixelText(
                displayValue,
                color: valueColor,
                cellSize: cellSize,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
