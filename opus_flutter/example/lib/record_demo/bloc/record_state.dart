import '../core/recorder_phase.dart';
import '../data/recording_storage.dart';

final class RecorderState {
  const RecorderState({
    this.phase = RecorderPhase.idle,
    this.opusStorage,
    this.wavStorage,
    this.wavReady = false,
    this.recordingDuration = Duration.zero,
    this.playbackDuration = Duration.zero,
    this.totalPlaybackDuration,
    this.error,
  });

  final RecorderPhase phase;
  final RecordingStorage? opusStorage;
  final RecordingStorage? wavStorage;

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
    RecordingStorage? Function()? opusStorage,
    RecordingStorage? Function()? wavStorage,
    bool? wavReady,
    Duration? recordingDuration,
    Duration? playbackDuration,
    Duration? Function()? totalPlaybackDuration,
    String? Function()? error,
  }) {
    return RecorderState(
      phase: phase ?? this.phase,
      opusStorage: opusStorage != null ? opusStorage() : this.opusStorage,
      wavStorage: wavStorage != null ? wavStorage() : this.wavStorage,
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
