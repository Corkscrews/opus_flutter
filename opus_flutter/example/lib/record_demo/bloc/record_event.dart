sealed class RecordEvent {
  const RecordEvent();
}

final class StartRecordingEvent extends RecordEvent {
  const StartRecordingEvent();
}

final class StopRecordingEvent extends RecordEvent {
  const StopRecordingEvent();
}

final class DecodeFromDiskEvent extends RecordEvent {
  const DecodeFromDiskEvent();
}

final class PlayDecodedFileEvent extends RecordEvent {
  const PlayDecodedFileEvent();
}

/// Internal event — fired every second by [RecordBloc] while recording.
/// Not intended to be dispatched from outside the BLoC.
final class RecordingTickEvent extends RecordEvent {
  const RecordingTickEvent();
}

/// Internal event — fired every second by [RecordBloc] while playing back.
/// Not intended to be dispatched from outside the BLoC.
final class PlaybackTickEvent extends RecordEvent {
  const PlaybackTickEvent();
}

/// Internal event — fired by [RecordBloc] when the audio player finishes.
/// Not intended to be dispatched from outside the BLoC.
final class PlaybackCompleteEvent extends RecordEvent {
  const PlaybackCompleteEvent();
}

/// Internal event — fired by [RecordBloc] once the player reports the total
/// duration of the loaded audio file.
/// Not intended to be dispatched from outside the BLoC.
final class PlaybackTotalDurationEvent extends RecordEvent {
  const PlaybackTotalDurationEvent(this.total);
  final Duration total;
}
