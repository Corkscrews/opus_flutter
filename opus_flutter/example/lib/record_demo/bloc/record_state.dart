import 'package:universal_io/io.dart';

import '../core/recorder_phase.dart';

final class RecorderState {
  const RecorderState({
    this.phase = RecorderPhase.idle,
    this.opusFile,
    this.wavFile,
    this.wavReady = false,
    this.recordingDuration = Duration.zero,
    this.playbackDuration = Duration.zero,
    this.totalPlaybackDuration,
    this.error,
  });

  final RecorderPhase phase;
  final File? opusFile;
  final File? wavFile;
  /// True only after a successful decode pass — gates the PLAY button.
  final bool wavReady;
  /// Elapsed time since the current recording started.
  final Duration recordingDuration;
  /// Elapsed time since the current playback started.
  final Duration playbackDuration;
  /// Total duration of the loaded WAV file; null until the player reports it.
  final Duration? totalPlaybackDuration;
  final String? error;

  String get statusText {
    if (error != null) return error!;
    return switch (phase) {
      RecorderPhase.idle => 'Idle',
      RecorderPhase.starting => 'Starting...',
      RecorderPhase.recording => 'REC ${_formatDuration(recordingDuration)}',
      RecorderPhase.stopping => 'Stopping...',
      RecorderPhase.decoding => 'Decoding...',
      RecorderPhase.playing => totalPlaybackDuration != null
          ? 'PLAYING ${_formatDuration(playbackDuration)} / ${_formatDuration(totalPlaybackDuration!)}'
          : 'PLAYING ${_formatDuration(playbackDuration)}',
    };
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  RecorderState copyWith({
    RecorderPhase? phase,
    File? Function()? opusFile,
    File? Function()? wavFile,
    bool? wavReady,
    Duration? recordingDuration,
    Duration? playbackDuration,
    Duration? Function()? totalPlaybackDuration,
    String? Function()? error,
  }) {
    return RecorderState(
      phase: phase ?? this.phase,
      opusFile: opusFile != null ? opusFile() : this.opusFile,
      wavFile: wavFile != null ? wavFile() : this.wavFile,
      wavReady: wavReady ?? this.wavReady,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      playbackDuration: playbackDuration ?? this.playbackDuration,
      totalPlaybackDuration: totalPlaybackDuration != null
          ? totalPlaybackDuration()
          : this.totalPlaybackDuration,
      error: error != null ? error() : this.error,
    );
  }
}
