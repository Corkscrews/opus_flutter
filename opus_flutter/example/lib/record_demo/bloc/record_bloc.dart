import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opus_dart/opus_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:universal_io/io.dart';

import '../core/audio_constants.dart';
import '../core/recorder_phase.dart';
import '../data/opus_packet_file.dart';
import '../data/opus_wav_codec.dart';
import 'record_event.dart';
import 'record_state.dart';

class RecordBloc extends Bloc<RecordEvent, RecorderState> {
  RecordBloc() : super(const RecorderState()) {
    on<StartRecordingEvent>(_onStartRecording);
    on<StopRecordingEvent>(_onStopRecording);
    on<DecodeFromDiskEvent>(_onDecodeFromDisk);
    on<PlayDecodedFileEvent>(_onPlayDecodedFile);
    on<RecordingTickEvent>(_onRecordingTick);
    on<PlaybackTickEvent>(_onPlaybackTick);
    on<PlaybackCompleteEvent>(_onPlaybackComplete);
    on<PlaybackTotalDurationEvent>(_onPlaybackTotalDuration);
  }

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  IOSink? _opusSink;
  StreamSubscription<Uint8List>? _encoderSubscription;
  Timer? _recordingTimer;
  Timer? _playbackTimer;
  StreamSubscription<void>? _playerCompleteSubscription;
  StreamSubscription<Duration>? _playerDurationSubscription;

  Future<void> _onStartRecording(
    StartRecordingEvent event,
    Emitter<RecorderState> emit,
  ) async {
    if (!state.phase.isIdle) return;

    emit(state.copyWith(
      phase: RecorderPhase.starting,
      error: () => null,
    ));

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw StateError('Microphone permission denied.');
      }

      final directory = await getApplicationDocumentsDirectory();
      final opusPath = '${directory.path}/recorded_audio.opuspack';
      final wavPath = '${directory.path}/decoded_audio.wav';
      final opusFile = File(opusPath);
      final wavFile = File(wavPath);

      if (await opusFile.exists()) await opusFile.delete();
      if (await wavFile.exists()) await wavFile.delete();

      final pcmStream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: demoSampleRate,
        numChannels: demoChannels,
      ));

      final sink = opusFile.openWrite(mode: FileMode.writeOnlyAppend);
      final encoded = pcmStream.cast<List<int>>().transform(
            StreamOpusEncoder.bytes(
              floatInput: false,
              frameTime: FrameTime.ms20,
              sampleRate: demoSampleRate,
              channels: demoChannels,
              application: Application.audio,
              copyOutput: true,
              fillUpLastFrame: true,
            ),
          );

      _opusSink = sink;
      _encoderSubscription = encoded.listen(
        (packet) => OpusPacketFile.writeLengthPrefixedPacket(sink, packet),
      );

      _recordingTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => add(const RecordingTickEvent()),
      );

      emit(state.copyWith(
        phase: RecorderPhase.recording,
        opusFile: () => opusFile,
        wavFile: () => wavFile,
        wavReady: false,
        recordingDuration: Duration.zero,
      ));
    } catch (error) {
      // ignore: avoid_print
      print('Failed to start recording: $error');
      emit(state.copyWith(
        phase: RecorderPhase.idle,
        error: () => 'Failed to start recording: $error',
      ));
    }
  }

  void _onRecordingTick(
    RecordingTickEvent event,
    Emitter<RecorderState> emit,
  ) {
    if (!state.phase.isRecording) return;
    emit(state.copyWith(
      recordingDuration: state.recordingDuration + const Duration(seconds: 1),
    ));
  }

  Future<void> _onStopRecording(
    StopRecordingEvent event,
    Emitter<RecorderState> emit,
  ) async {
    if (!state.phase.isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    emit(state.copyWith(
      phase: RecorderPhase.stopping,
      error: () => null,
    ));

    try {
      await _recorder.stop();
      await _encoderSubscription?.asFuture<void>();
      await _opusSink?.flush();
      await _opusSink?.close();
    } catch (error) {
      emit(state.copyWith(error: () => 'Failed to stop recording: $error'));
    } finally {
      _encoderSubscription = null;
      _opusSink = null;
      emit(state.copyWith(phase: RecorderPhase.idle));
    }
  }

  Future<void> _onDecodeFromDisk(
    DecodeFromDiskEvent event,
    Emitter<RecorderState> emit,
  ) async {
    if (!state.phase.isIdle) return;
    final opusFile = state.opusFile;
    final wavFile = state.wavFile;

    if (opusFile == null || wavFile == null || !await opusFile.exists()) {
      emit(state.copyWith(
        error: () => 'No Opus recording found. Record audio first.',
      ));
      return;
    }

    emit(state.copyWith(
      phase: RecorderPhase.decoding,
      error: () => null,
    ));

    try {
      final bytes = await opusFile.readAsBytes();
      final packets = OpusPacketFile.readLengthPrefixedPackets(bytes);
      final decodedWav = await OpusWavCodec.decodePacketsToWav(packets);
      await wavFile.writeAsBytes(decodedWav, flush: true);
      emit(state.copyWith(phase: RecorderPhase.idle, wavReady: true));
    } catch (error) {
      emit(state.copyWith(
        phase: RecorderPhase.idle,
        error: () => 'Failed to decode Opus file: $error',
      ));
    }
  }

  Future<void> _onPlayDecodedFile(
    PlayDecodedFileEvent event,
    Emitter<RecorderState> emit,
  ) async {
    if (!state.phase.isIdle) return;
    final wavFile = state.wavFile;

    if (wavFile == null || !await wavFile.exists()) {
      emit(state.copyWith(
        error: () => 'No decoded WAV found. Decode from disk first.',
      ));
      return;
    }

    emit(state.copyWith(
      phase: RecorderPhase.playing,
      playbackDuration: Duration.zero,
      totalPlaybackDuration: () => null,
      error: () => null,
    ));

    try {
      await _player.stop();

      _playerCompleteSubscription = _player.onPlayerComplete
          .listen((_) => add(const PlaybackCompleteEvent()));

      _playerDurationSubscription = _player.onDurationChanged
          .listen((d) => add(PlaybackTotalDurationEvent(d)));

      _playbackTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => add(const PlaybackTickEvent()),
      );

      await _player.play(DeviceFileSource(wavFile.path));
    } catch (error) {
      _cancelPlayback();
      emit(state.copyWith(
        phase: RecorderPhase.idle,
        error: () => 'Failed to play decoded audio: $error',
      ));
    }
  }

  void _onPlaybackTick(
    PlaybackTickEvent event,
    Emitter<RecorderState> emit,
  ) {
    if (!state.phase.isPlaying) return;
    emit(state.copyWith(
      playbackDuration: state.playbackDuration + const Duration(seconds: 1),
    ));
  }

  void _onPlaybackComplete(
    PlaybackCompleteEvent event,
    Emitter<RecorderState> emit,
  ) {
    _cancelPlayback();
    emit(state.copyWith(phase: RecorderPhase.idle));
  }

  void _onPlaybackTotalDuration(
    PlaybackTotalDurationEvent event,
    Emitter<RecorderState> emit,
  ) {
    if (!state.phase.isPlaying) return;
    emit(state.copyWith(totalPlaybackDuration: () => event.total));
  }

  void _cancelPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playerCompleteSubscription?.cancel();
    _playerCompleteSubscription = null;
    _playerDurationSubscription?.cancel();
    _playerDurationSubscription = null;
  }

  @override
  Future<void> close() async {
    _recordingTimer?.cancel();
    _cancelPlayback();
    await _encoderSubscription?.cancel();
    await _opusSink?.close();
    _recorder.dispose();
    _player.dispose();
    return super.close();
  }
}
