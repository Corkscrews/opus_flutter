import 'dart:async';
import 'dart:typed_data';

import 'opus_dart_encoder.dart';
import 'opus_dart_decoder.dart';
import 'opus_dart_misc.dart';

/// Represents different frame times supported by opus.
enum FrameTime {
  /// 2.5ms
  ms2_5,
  // 5ms
  ms5,
  // 10ms
  ms10,
  // 20ms
  ms20,
  // 40ms
  ms40,
  // 60ms
  ms60
}

/// Used to encode a stream of pcm data to opus frames of constant time.
/// Each StreamOpusEncoder MUST ONLY be used once!
class StreamOpusEncoder<T>
    extends StreamTransformerBase<List<T>, Uint8List> {
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

  /// If `true`, the encoded output is copied into dart memory befor passig it to any consumers.
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

  @override
  Stream<Uint8List> bind(Stream<List<T>> stream) async* {
    try {
      int dataIndex;
      Uint8List bytes;
      int available;
      int max;
      int use;
      Uint8List inputBuffer = _encoder.inputBuffer;
      Stream<Uint8List> mapped;
      if (_expect == Int16List) {
        mapped = stream.cast<Int16List>().map((Int16List s16le) =>
            s16le.buffer.asUint8List(s16le.offsetInBytes, s16le.lengthInBytes));
      } else if (_expect == Float32List) {
        mapped = stream.cast<Float32List>().map((Float32List floats) => floats
            .buffer
            .asUint8List(floats.offsetInBytes, floats.lengthInBytes));
      } else {
        mapped = stream.cast<Uint8List>();
      }
      await for (Uint8List pcm in mapped) {
        bytes = pcm;
        dataIndex = 0;
        available = bytes.lengthInBytes;
        while (available > 0) {
          max = _encoder.maxInputBufferSizeBytes - _encoder.inputBufferIndex;
          use = max < available ? max : available;
          inputBuffer.setRange(_encoder.inputBufferIndex,
              _encoder.inputBufferIndex + use, bytes, dataIndex);
          dataIndex += use;
          _encoder.inputBufferIndex += use;
          available = bytes.lengthInBytes - dataIndex;
          if (_encoder.inputBufferIndex == _encoder.maxInputBufferSizeBytes) {
            Uint8List bytes =
                floats ? _encoder.encodeFloat() : _encoder.encode();
            yield copyOutput ? Uint8List.fromList(bytes) : bytes;
            _encoder.inputBufferIndex = 0;
          }
        }
      }
      if (_encoder.maxInputBufferSizeBytes != 0) {
        if (fillUpLastFrame) {
          _encoder.inputBuffer.setAll(
              _encoder.inputBufferIndex,
              Uint8List(_encoder.maxInputBufferSizeBytes -
                  _encoder.inputBufferIndex));
          _encoder.inputBufferIndex = _encoder.maxInputBufferSizeBytes;
          Uint8List bytes =
              floats ? _encoder.encodeFloat() : _encoder.encode();
          yield copyOutput ? Uint8List.fromList(bytes) : bytes;
        } else {
          int missingSamples =
              (_encoder.maxInputBufferSizeBytes - _encoder.inputBufferIndex) ~/
                  (floats ? 4 : 2);
          throw UnfinishedFrameException._(missingSamples: missingSamples);
        }
      }
    } finally {
      destroy();
    }
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
class StreamOpusDecoder
    extends StreamTransformerBase<Uint8List?, List<num>> {
  /// If forward error correction (fec) should be enabled.
  final bool forwardErrorCorrection;

  /// Indicates if the input data is decoded to floats (`true`) or to s16le (`false`).
  final bool floats;

  /// If `true`, the decoded output is copied into dart memory befor passig it to any consumers.
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
      : this._(true, Float32List, sampleRate, channels,
            forwardErrorCorrection, copyOutput, autoSoftClip);

  /// Creates a new StreamOpusDecoder that outputs [Int16List].
  StreamOpusDecoder.s16le(
      {required int sampleRate,
      required int channels,
      bool forwardErrorCorrection = false,
      bool copyOutput = true})
      : this._(false, Int16List, sampleRate, channels,
            forwardErrorCorrection, copyOutput, false);

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
                (floats ? 2 : 4) * maxSamplesPerPacket(sampleRate, channels));

  void _reportPacketLoss() {
    if (floats) {
      _decoder.decodeFloat(
          fec: false,
          loss: _decoder.lastPacketDurationMs,
          autoSoftClip: autoSoftClip);
    } else {
      _decoder.decode(fec: false, loss: _decoder.lastPacketDurationMs);
    }
  }

  List<num> _output() {
    Uint8List output = _decoder.outputBuffer;
    if (copyOutput) {
      output = Uint8List.fromList(output);
    }
    if (_outputType == Float32List) {
      return output.buffer
          .asFloat32List(output.offsetInBytes, output.lengthInBytes ~/ 4);
    } else if (_outputType == Int16List) {
      return output.buffer
          .asInt16List(output.offsetInBytes, output.lengthInBytes ~/ 2);
    } else {
      return output;
    }
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
      } else {
        _decoder.inputBuffer.setAll(0, packet);
        _decoder.inputBufferIndex = packet.length;
        if (_lastPacketLost && forwardErrorCorrection) {
          if (floats) {
            _decoder.decodeFloat(
                fec: true, loss: _decoder.lastPacketDurationMs);
          } else {
            _decoder.decode(fec: true, loss: _decoder.lastPacketDurationMs);
          }
          yield _output();
        }
        _lastPacketLost = false;
        if (floats) {
          _decoder.decodeFloat(fec: false);
        } else {
          _decoder.decode(fec: false);
        }
        yield _output();
      }
    }
  }
}
