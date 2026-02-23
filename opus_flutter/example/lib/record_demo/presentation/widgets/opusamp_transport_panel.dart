import 'package:flutter/material.dart';

import '../../app/record_demo_app.dart';
import '../../core/recorder_phase.dart';
import '../../data/recording_storage.dart';
import 'opusamp_file_info.dart';
import 'opusamp_lcd.dart';
import 'opusamp_speaker.dart';
import 'opusamp_transport_button.dart'
    show ButtonIndicator, OpusampTransportButton;

class OpusampTransportPanel extends StatelessWidget {
  const OpusampTransportPanel({
    super.key,
    required this.phase,
    required this.statusText,
    required this.opusStorage,
    required this.wavStorage,
    required this.onRecord,
    required this.onStop,
    required this.onDecode,
    required this.onPlay,
  });

  final RecorderPhase phase;
  final String statusText;
  final RecordingStorage? opusStorage;
  final RecordingStorage? wavStorage;
  final VoidCallback? onRecord;
  final VoidCallback? onStop;
  final VoidCallback? onDecode;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OpusampLcd(phase: phase, statusText: statusText),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: opusampDarkGray,
            border: Border(
              left: BorderSide(color: Color(0xFF555555)),
              right: BorderSide(color: Color(0xFF111111)),
              bottom: BorderSide(color: Color(0xFF111111)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OpusampFileInfo(
                          opusStorage: opusStorage, wavStorage: wavStorage),
                    ),
                    const SizedBox(width: 4),
                    const OpusampSpeaker(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OpusampTransportButton(
                    onPressed: onStop ?? onRecord,
                    label: 'REC',
                    activeColor: phase.isRecording
                        ? opusampRed
                        : const Color(0xFF5A1010),
                    indicator: ButtonIndicator.dot,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  OpusampTransportButton(
                    onPressed: onDecode,
                    label: 'DECODE',
                  ),
                  const SizedBox(width: 3),
                  OpusampTransportButton(
                    onPressed: onPlay,
                    label: 'PLAY',
                    activeColor:
                        phase.isPlaying ? opusampGreen : opusampGreenDim,
                    indicator: ButtonIndicator.arrow,
                    lockColor: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
