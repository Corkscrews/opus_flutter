import 'dart:async';
import 'dart:typed_data';

import 'opus_dart_encoder.dart';
import 'opus_dart_decoder.dart';
import 'opus_dart_misc.dart';

/// Represents different frame times supported by opus.
enum FrameTime {
  /// 2.5ms
  ms2_5,

  /// 5ms
  ms5,

  /// 10ms
  ms10,

  /// 20ms
  ms20,

  /// 40ms
  ms40,

  /// 60ms
  ms60
}

/// Used to encode a stream of pcm data to opus frames of constant time.
/// Each StreamOpusEncoder MUST ONLY be used once!
class StreamOpusEncoder<T> extends StreamTransformerBase<List<T>, Uint8List> {
  static int _calculateMaxSampleSize(
      int sampleRate, int channels, FrameTime frameTime) {
    int samplesPerMs = (channels * sampleRate) ~/ 1000;
    switch (frameTime) {
      case FrameTime.ms2_5:
        return 2 * samplesPerMs + (samplesPerMs ~/ 2);
      case FrameTime.ms5:
        return 5 * samplesPerMs;
      case FrameTime.ms10:
        return 10 * samplesPerMs;
      case FrameTime.ms20:
        return 20 * samplesPerMs;
      case FrameTime.ms40:
        return 40 * samplesPerMs;
      case FrameTime.ms60:
        return 60 * samplesPerMs;
    }
  }

  final BufferedOpusEncoder _encoder;
  final Type _expect;

  /// The frames time determines, how much data need to be buffered before producing an encoded opus packet.
  final FrameTime frameTime;

  /// If the underlying stream is closed and this is `true`, the missing samples are filled up with zero to produce a final frame.
  final bool fillUpLastFrame;

  /// Indicates if the input data is interpreted as floats (`true`) or as s16le (`false`).
  final bool floats;

  /// Previously controlled whether output was copied into Dart memory.
  /// Output is now always copied for safety (prevents use-after-write hazards
  /// when the native buffer is overwritten on the next encode call).
  final bool copyOutput;

  /// The sample rate in Hz for this encoder.
  int get sampleRate => _encoder.sampleRate;

  /// Number of channels, must be 1 for mono or 2 for stereo.
  int get channels => _encoder.channels;

  /// The kind of application for which this encoders output is used.
  Application get application => _encoder.application;

  /// Creates a new StreamOpusEncoder that expects its input Lists to be [Float32List].
  StreamOpusEncoder.float(
      {required FrameTime frameTime,
      required int sampleRate,
      required int channels,
      required Application application,
      bool fillUpLastFrame = true,
      bool copyOutput = true})
      : this._(frameTime, true, Float32List, sampleRate, channels, application,
            fillUpLastFrame, copyOutput);

  /// Creates a new StreamOpusEncoder that expects its input Lists to be [Int16List].
  StreamOpusEncoder.s16le(
      {required FrameTime frameTime,
      required int sampleRate,
      required int channels,
      required Application application,
      bool fillUpLastFrame = true,
      bool copyOutput = true})
      : this._(frameTime, false, Int16List, sampleRate, channels, application,
            fillUpLastFrame, copyOutput);

  /// Creates a new StreamOpusEncoder that expects its input Lists to be bytes
  /// in form of [Uint8List].
  StreamOpusEncoder.bytes(
      {required FrameTime frameTime,
      required bool floatInput,
      required int sampleRate,
      required int channels,
      required Application application,
      bool fillUpLastFrame = true,
      bool copyOutput = true})
      : this._(frameTime, floatInput, Uint8List, sampleRate, channels,
            application, fillUpLastFrame, copyOutput);

  StreamOpusEncoder._(
      this.frameTime,
      this.floats,
      this._expect,
      int sampleRate,
      int channels,
      Application application,
      this.fillUpLastFrame,
      this.copyOutput)
      : _encoder = BufferedOpusEncoder(
            sampleRate: sampleRate,
            channels: channels,
            application: application,
            maxInputBufferSizeBytes: (floats ? 4 : 2) *
                _calculateMaxSampleSize(sampleRate, channels, frameTime));

  /// Transforms an incoming PCM stream into encoded opus packets.
  ///
  /// The pipeline works in three stages:
  /// 1. **Map** — converts typed input ([Int16List], [Float32List], or
  ///    [Uint8List]) into a uniform byte stream via [_mapStream].
  /// 2. **Buffer & encode** — each byte chunk is fed into the encoder's
  ///    fixed-size input buffer via [_processChunk]. Every time the buffer
  ///    fills to exactly one frame, the frame is encoded and yielded.
  /// 3. **Flush** — when the source stream closes, [_flushRemaining] handles
  ///    the partial frame: either zero-pads and encodes it
  ///    ([fillUpLastFrame] = true) or throws [UnfinishedFrameException].
  ///
  /// The encoder is always destroyed in the `finally` block, regardless of
  /// whether the stream completes normally or with an error.
  @override
  Stream<Uint8List> bind(Stream<List<T>> stream) async* {
    try {
      await for (Uint8List pcm in _mapStream(stream)) {
        for (final packet in _processChunk(pcm)) {
          yield packet;
        }
      }
      for (final packet in _flushRemaining()) {
        yield packet;
      }
    } finally {
      destroy();
    }
  }

  /// Converts the typed input stream into a uniform [Stream<Uint8List>].
  ///
  /// [Int16List] and [Float32List] elements are reinterpreted as their raw
  /// byte representation without copying. [Uint8List] elements pass through
  /// unchanged.
  Stream<Uint8List> _mapStream(Stream<List<T>> stream) {
    if (_expect == Int16List) {
      return stream.cast<Int16List>().map((s16le) =>
          s16le.buffer.asUint8List(s16le.offsetInBytes, s16le.lengthInBytes));
    }
    if (_expect == Float32List) {
      return stream.cast<Float32List>().map((f32) =>
          f32.buffer.asUint8List(f32.offsetInBytes, f32.lengthInBytes));
    }
    return stream.cast<Uint8List>();
  }

  /// Feeds [pcm] bytes into the encoder's input buffer, encoding and yielding
  /// a packet each time the buffer fills to one complete frame.
  ///
  /// A single chunk may span multiple frames (e.g. a large audio buffer), so
  /// this may yield zero or more encoded packets. Leftover bytes that don't
  /// complete a frame remain in the encoder's input buffer for the next chunk.
  Iterable<Uint8List> _processChunk(Uint8List pcm) sync* {
    int offset = 0;
    int remaining = pcm.lengthInBytes;
    while (remaining > 0) {
      final space =
          _encoder.maxInputBufferSizeBytes - _encoder.inputBufferIndex;
      final count = space < remaining ? space : remaining;
      _encoder.inputBuffer.setRange(_encoder.inputBufferIndex,
          _encoder.inputBufferIndex + count, pcm, offset);
      offset += count;
      _encoder.inputBufferIndex += count;
      remaining -= count;
      if (_encoder.inputBufferIndex == _encoder.maxInputBufferSizeBytes) {
        yield _encodeCurrentBuffer();
        _encoder.inputBufferIndex = 0;
      }
    }
  }

  /// Encodes the encoder's current input buffer and returns a Dart-heap copy
  /// of the resulting opus packet.
  Uint8List _encodeCurrentBuffer() {
    final encoded = floats ? _encoder.encodeFloat() : _encoder.encode();
    return Uint8List.fromList(encoded);
  }

  /// Handles the end-of-stream partial frame.
  ///
  /// If [fillUpLastFrame] is true, the remaining buffer space is zero-padded
  /// to produce one final silent-padded frame. Otherwise, an
  /// [UnfinishedFrameException] is thrown reporting how many samples are
  /// missing.
  Iterable<Uint8List> _flushRemaining() sync* {
    if (_encoder.maxInputBufferSizeBytes == 0) return;
    if (!fillUpLastFrame) {
      final missingSamples =
          (_encoder.maxInputBufferSizeBytes - _encoder.inputBufferIndex) ~/
              (floats ? 4 : 2);
      throw UnfinishedFrameException._(missingSamples: missingSamples);
    }
    _padInputBuffer();
    yield _encodeCurrentBuffer();
  }

  /// Fills the remaining input buffer space with silence (zeros) and marks
  /// the buffer as full.
  void _padInputBuffer() {
    final padding =
        _encoder.maxInputBufferSizeBytes - _encoder.inputBufferIndex;
    _encoder.inputBuffer.setAll(_encoder.inputBufferIndex, Uint8List(padding));
    _encoder.inputBufferIndex = _encoder.maxInputBufferSizeBytes;
  }

  /// Manually destroys this encoder.
  void destroy() => _encoder.destroy();
}

/// Thrown if an [StreamOpusEncoder] finished with insufficient samples left to produce a final frame.
class UnfinishedFrameException implements Exception {
  /// The amount of samples that are missing for the final frame.
  final int missingSamples;
  const UnfinishedFrameException._({required this.missingSamples});

  @override
  String toString() {
    return 'UnfinishedFrameException: The source stream is closed, but there are $missingSamples samples missing to encode the next frame';
  }
}

/// Used to decode a stream of opus packets to pcm data.
/// Each element in the input stream MUST contain a whole opus packet.
/// A `null` element in the input stream is interpreted as packet loss.
class StreamOpusDecoder extends StreamTransformerBase<Uint8List?, List<num>> {
  /// If forward error correction (fec) should be enabled.
  final bool forwardErrorCorrection;

  /// Indicates if the input data is decoded to floats (`true`) or to s16le (`false`).
  final bool floats;

  /// Previously controlled whether output was copied into Dart memory.
  /// Output is now always copied for safety (prevents use-after-write hazards
  /// when the native buffer is overwritten on the next decode call, and prevents
  /// data corruption in the FEC double-yield path).
  final bool copyOutput;

  /// The sample rate in Hz for this decoder.
  int get sampleRate => _decoder.sampleRate;

  /// Number of channels, must be 1 for mono or 2 for stereo.
  int get channels => _decoder.channels;

  /// If the packet is decoded to floats, autoSoftClip can be set to `true`.
  final bool autoSoftClip;

  final BufferedOpusDecoder _decoder;

  bool _lastPacketLost;

  final Type _outputType;

  /// Creates a new StreamOpusDecoder that outputs [Float32List].
  StreamOpusDecoder.float(
      {required int sampleRate,
      required int channels,
      bool forwardErrorCorrection = false,
      bool copyOutput = true,
      bool autoSoftClip = false})
      : this._(true, Float32List, sampleRate, channels, forwardErrorCorrection,
            copyOutput, autoSoftClip);

  /// Creates a new StreamOpusDecoder that outputs [Int16List].
  StreamOpusDecoder.s16le(
      {required int sampleRate,
      required int channels,
      bool forwardErrorCorrection = false,
      bool copyOutput = true})
      : this._(false, Int16List, sampleRate, channels, forwardErrorCorrection,
            copyOutput, false);

  /// Creates a new StreamOpusDecoder that outputs plain bytes (in form of [Uint8List]).
  StreamOpusDecoder.bytes(
      {required bool floatOutput,
      required int sampleRate,
      required int channels,
      bool forwardErrorCorrection = false,
      bool copyOutput = true,
      bool autoSoftClip = false})
      : this._(
            floatOutput,
            Uint8List,
            sampleRate,
            channels,
            forwardErrorCorrection,
            copyOutput,
            floatOutput == true ? autoSoftClip : false);

  StreamOpusDecoder._(
      this.floats,
      this._outputType,
      int sampleRate,
      int channels,
      this.forwardErrorCorrection,
      this.copyOutput,
      this.autoSoftClip)
      : _lastPacketLost = false,
        _decoder = BufferedOpusDecoder(
            sampleRate: sampleRate,
            channels: channels,
            maxOutputBufferSizeBytes:
                (floats ? 4 : 2) * maxSamplesPerPacket(sampleRate, channels));

  void _reportPacketLoss() {
    _decodeFec(false, loss: _decoder.lastPacketDurationMs);
  }

  void _decodeFec(bool fec, {int? loss}) {
    if (floats) {
      _decoder.decodeFloat(fec: fec, loss: loss, autoSoftClip: autoSoftClip);
      return;
    }
    _decoder.decode(fec: fec, loss: loss);
  }

  List<num> _output() {
    Uint8List output = Uint8List.fromList(_decoder.outputBuffer);
    if (_outputType == Float32List) {
      return output.buffer
          .asFloat32List(output.offsetInBytes, output.lengthInBytes ~/ 4);
    }
    if (_outputType == Int16List) {
      return output.buffer
          .asInt16List(output.offsetInBytes, output.lengthInBytes ~/ 2);
    }
    return output;
  }

  @override
  Stream<List<num>> bind(Stream<Uint8List?> stream) async* {
    await for (Uint8List? packet in stream) {
      if (packet == null) {
        if (forwardErrorCorrection) {
          _decoder.inputBufferIndex = 0;
          if (_lastPacketLost) {
            _reportPacketLoss();
          }
        } else {
          _reportPacketLoss();
        }
        _lastPacketLost = true;
        continue;
      }
      _decoder.inputBuffer.setAll(0, packet);
      _decoder.inputBufferIndex = packet.length;
      if (_lastPacketLost && forwardErrorCorrection) {
        _decodeFec(true);
        yield _output();
      }
      _lastPacketLost = false;
      _decodeFec(false);
      yield _output();
    }
  }
}
