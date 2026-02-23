import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opus_codec_dart/opus_codec_dart.dart';
import 'package:record/record.dart';

import '../core/audio_constants.dart';
import '../core/recorder_phase.dart';
import '../data/opus_packet_file.dart';
import '../data/opus_wav_codec.dart';
import '../data/recording_storage.dart';
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

  RecordingDataSink? _opusSink;
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

      final opusStorage =
          await RecordingStorage.create('recorded_audio.opuspack');
      final wavStorage = await RecordingStorage.create('decoded_audio.wav');

      if (await opusStorage.exists()) await opusStorage.delete();
      if (await wavStorage.exists()) await wavStorage.delete();

      final pcmStream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: demoSampleRate,
        numChannels: demoChannels,
      ));

      final sink = opusStorage.openWrite();
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
        opusStorage: () => opusStorage,
        wavStorage: () => wavStorage,
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
    final opusStorage = state.opusStorage;
    final wavStorage = state.wavStorage;

    if (opusStorage == null ||
        wavStorage == null ||
        !await opusStorage.exists()) {
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
      final bytes = await opusStorage.readAsBytes();
      final packets = OpusPacketFile.readLengthPrefixedPackets(bytes);
      final decodedWav = await OpusWavCodec.decodePacketsToWav(packets);
      final wavSink = wavStorage.openWrite();
      wavSink.add(decodedWav);
      await wavSink.flush();
      await wavSink.close();
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
    final wavStorage = state.wavStorage;

    if (wavStorage == null || !await wavStorage.exists()) {
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

      if (kIsWeb) {
        final bytes = await wavStorage.readAsBytes();
        await _player.play(BytesSource(bytes));
      } else {
        await _player.play(DeviceFileSource(wavStorage.label));
      }
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
