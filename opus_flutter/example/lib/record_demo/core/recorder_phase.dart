enum RecorderPhase {
  idle,
  starting,
  recording,
  stopping,
  decoding,
  playing;

  bool get isBusy => this != idle && this != recording;
  bool get isRecording => this == recording;
  bool get isPlaying => this == playing;
  bool get isIdle => this == idle;
}
