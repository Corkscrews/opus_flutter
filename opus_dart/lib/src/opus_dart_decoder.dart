import 'proxy_ffi.dart';
import 'dart:typed_data';
import '../wrappers/opus_decoder.dart' as opus_decoder;
import '../wrappers/opus_defines.dart' as opus_defines;
import 'opus_dart_misc.dart';

int _packetDuration(int samples, int channels, int sampleRate) =>
    ((1000 * samples) ~/ (channels)) ~/ sampleRate;

/// Soft clips the [input] to a range from -1 to 1 and returns
/// the result.
///
/// If the samples are already in this range, nothing happens
/// to the samples.
///
/// [input] is copied into native memory.
/// If you are using a [BufferedOpusDecoder], take a look at it's [pcmSoftClipOutputBuffer]
/// method instead, since it avoids unnecessary memory copying.
Float32List pcmSoftClip({required Float32List input, required int channels}) {
  Pointer nativePcm = opus.allocator.call(input.length);
  nativePcm.asTypedList(input.length).setAll(0, input);
  Pointer nativeBuffer = opus.allocator.call(channels);
  try {
    opus.decoder.opus_pcm_soft_clip(
        nativePcm, input.length ~/ channels, channels, nativeBuffer);
    return Float32List.fromList(nativePcm.asTypedList(input.length));
  } finally {
    opus.allocator.free(nativePcm);
    opus.allocator.free(nativeBuffer);
  }
}

/// An easy to use implementation of [OpusDecoder].
/// Don't forget to call [destroy] once you are done with it.
///
/// All method calls in this calls allocate their own memory everytime they are called.
/// See the [BufferedOpusDecoder] for an implementation with less allocation calls.
class SimpleOpusDecoder extends OpusDecoder {
  final Pointer _opusDecoder;
  @override
  final int sampleRate;
  @override
  final int channels;
  bool _destroyed;
  @override
  bool get destroyed => _destroyed;
  @override
  int? get lastPacketDurationMs => _lastPacketDurationMs;
  int? _lastPacketDurationMs;

  final Pointer _softClipBuffer;

  final int _maxSamplesPerPacket;

  SimpleOpusDecoder._(
      this._opusDecoder, this.sampleRate, this.channels, this._softClipBuffer)
      : _destroyed = false,
        _maxSamplesPerPacket = maxSamplesPerPacket(sampleRate, channels);

  /// Creates an new [SimpleOpusDecoder] based on the [sampleRate] and [channels].
  /// See the matching fields for more information about these parameters.
  factory SimpleOpusDecoder({required int sampleRate, required int channels}) {
    Pointer error = opus.allocator.call(1);
    Pointer softClipBuffer = opus.allocator.call(channels);
    Pointer decoder =
        opus.decoder.opus_decoder_create(sampleRate, channels, error);
    try {
      if (error.value == opus_defines.OPUS_OK) {
        return SimpleOpusDecoder._(
            decoder, sampleRate, channels, softClipBuffer);
      } else {
        opus.allocator.free(softClipBuffer);
        throw OpusException(error.value);
      }
    } finally {
      opus.allocator.free(error);
    }
  }

  /// Decodes an opus packet to s16le samples, represented as [Int16List].
  /// Use `null` as [input] to indicate packet loss.
  @override
  Int16List decode({Uint8List? input, bool fec = false, int? loss}) {
    Pointer outputNative =
        opus.allocator.call(_maxSamplesPerPacket);
    Pointer inputNative;
    if (input != null) {
      inputNative = opus.allocator.call(input.length);
      inputNative.asTypedList(input.length).setAll(0, input);
    } else {
      inputNative = nullptr;
    }
    int frameSize;
    if (input == null || fec) {
      frameSize = _estimateLoss(loss, lastPacketDurationMs);
    } else {
      frameSize = _maxSamplesPerPacket;
    }
    int outputSamplesPerChannel = opus.decoder.opus_decode(_opusDecoder,
        inputNative, input?.length ?? 0, outputNative, frameSize, fec ? 1 : 0);
    try {
      if (outputSamplesPerChannel >= opus_defines.OPUS_OK) {
        _lastPacketDurationMs =
            _packetDuration(outputSamplesPerChannel, channels, sampleRate);
        return Int16List.fromList(
            outputNative.asTypedList(outputSamplesPerChannel * channels));
      } else {
        throw OpusException(outputSamplesPerChannel);
      }
    } finally {
      opus.allocator.free(inputNative);
      opus.allocator.free(outputNative);
    }
  }

  /// Decodes an opus packet to float samples, represented as [Float32List].
  /// Use `null` as [input] to indicate packet loss.
  ///
  /// If [autoSoftClip] is true, softcliping is applied to the output.
  @override
  Float32List decodeFloat(
      {Uint8List? input,
      bool fec = false,
      bool autoSoftClip = false,
      int? loss}) {
    Pointer outputNative =
        opus.allocator.call(_maxSamplesPerPacket);
    Pointer inputNative;
    if (input != null) {
      inputNative = opus.allocator.call(input.length);
      inputNative.asTypedList(input.length).setAll(0, input);
    } else {
      inputNative = nullptr;
    }
    int frameSize;
    if (input == null || fec) {
      frameSize = _estimateLoss(loss, lastPacketDurationMs);
    } else {
      frameSize = _maxSamplesPerPacket;
    }
    int outputSamplesPerChannel = opus.decoder.opus_decode_float(_opusDecoder,
        inputNative, input?.length ?? 0, outputNative, frameSize, fec ? 1 : 0);
    try {
      if (outputSamplesPerChannel >= opus_defines.OPUS_OK) {
        _lastPacketDurationMs =
            _packetDuration(outputSamplesPerChannel, channels, sampleRate);
        if (autoSoftClip) {
          opus.decoder.opus_pcm_soft_clip(outputNative,
              outputSamplesPerChannel ~/ channels, channels, _softClipBuffer);
        }
        return Float32List.fromList(
            outputNative.asTypedList(outputSamplesPerChannel * channels));
      } else {
        throw OpusException(outputSamplesPerChannel);
      }
    } finally {
      opus.allocator.free(inputNative);
      opus.allocator.free(outputNative);
    }
  }

  @override
  void destroy() {
    if (!_destroyed) {
      _destroyed = true;
      opus.decoder.opus_decoder_destroy(_opusDecoder);
      opus.allocator.free(_softClipBuffer);
    }
  }
}

/// An implementation of [OpusDecoder] that uses preallocated buffers.
/// Don't forget to call [destroy] once you are done with it.
class BufferedOpusDecoder extends OpusDecoder {
  final Pointer _opusDecoder;
  @override
  final int sampleRate;
  @override
  final int channels;
  bool _destroyed;
  @override
  bool get destroyed => _destroyed;
  @override
  int? get lastPacketDurationMs => _lastPacketDurationMs;
  int? _lastPacketDurationMs;

  /// The size of the allocated the input buffer in bytes.
  final int maxInputBufferSizeBytes;

  /// Indicates, how many bytes of data are currently stored in the [inputBuffer].
  int inputBufferIndex;

  final Pointer _inputBuffer;

  /// Returns the native input buffer backed by native memory.
  Uint8List get inputBuffer =>
      _inputBuffer.asTypedList(maxInputBufferSizeBytes);

  /// The size of the allocated the output buffer.
  final int maxOutputBufferSizeBytes;
  int _outputBufferIndex;
  final Pointer _outputBuffer;

  /// The portion of the allocated output buffer that is currently filled with data.
  Uint8List get outputBuffer => _outputBuffer.asTypedList(_outputBufferIndex);

  /// Convenience method to get the current output buffer as s16le.
  Int16List get outputBufferAsInt16List =>
      _outputBuffer.cast().asTypedList(_outputBufferIndex ~/ 2);

  /// Convenience method to get the current output buffer as floats.
  Float32List get outputBufferAsFloat32List =>
      _outputBuffer.cast().asTypedList(_outputBufferIndex ~/ 4);

  final Pointer _softClipBuffer;

  BufferedOpusDecoder._(
      this._opusDecoder,
      this.sampleRate,
      this.channels,
      this._inputBuffer,
      this.maxInputBufferSizeBytes,
      this._outputBuffer,
      this.maxOutputBufferSizeBytes,
      this._softClipBuffer)
      : _destroyed = false,
        inputBufferIndex = 0,
        _outputBufferIndex = 0;

  /// Creates an new [BufferedOpusDecoder] based on the [sampleRate] and [channels].
  factory BufferedOpusDecoder(
      {required int sampleRate,
      required int channels,
      int? maxInputBufferSizeBytes,
      int? maxOutputBufferSizeBytes}) {
    maxInputBufferSizeBytes ??= maxDataBytes;
    maxOutputBufferSizeBytes ??= maxSamplesPerPacket(sampleRate, channels);
    Pointer error = opus.allocator.call(1);
    Pointer input = opus.allocator.call(maxInputBufferSizeBytes);
    Pointer output = opus.allocator.call(maxOutputBufferSizeBytes);
    Pointer softClipBuffer = opus.allocator.call(channels);
    Pointer encoder =
        opus.decoder.opus_decoder_create(sampleRate, channels, error);
    try {
      if (error.value == opus_defines.OPUS_OK) {
        return BufferedOpusDecoder._(
            encoder,
            sampleRate,
            channels,
            input,
            maxInputBufferSizeBytes,
            output,
            maxOutputBufferSizeBytes,
            softClipBuffer);
      } else {
        opus.allocator.free(input);
        opus.allocator.free(output);
        opus.allocator.free(softClipBuffer);
        throw OpusException(error.value);
      }
    } finally {
      opus.allocator.free(error);
    }
  }

  /// Interpretes [inputBufferIndex] bytes from the [inputBuffer] as a whole
  /// opus packet and decodes them to s16le samples, stored in the [outputBuffer].
  /// Set [inputBufferIndex] to `0` to indicate packet loss.
  @override
  Int16List decode({bool fec = false, int? loss}) {
    Pointer inputNative;
    int frameSize;
    if (inputBufferIndex > 0) {
      inputNative = _inputBuffer;
      frameSize = maxOutputBufferSizeBytes ~/ (2 * channels);
    } else {
      inputNative = nullptr;
      frameSize = _estimateLoss(loss, lastPacketDurationMs);
    }
    int outputSamplesPerChannel = opus.decoder.opus_decode(
        _opusDecoder,
        inputNative,
        inputBufferIndex,
        _outputBuffer.cast(),
        frameSize,
        fec ? 1 : 0);
    if (outputSamplesPerChannel >= opus_defines.OPUS_OK) {
      _lastPacketDurationMs =
          _packetDuration(outputSamplesPerChannel, channels, sampleRate);
      _outputBufferIndex = 2 * outputSamplesPerChannel * channels;
      return outputBufferAsInt16List;
    } else {
      throw OpusException(outputSamplesPerChannel);
    }
  }

  /// Interpretes [inputBufferIndex] bytes from the [inputBuffer] as a whole
  /// opus packet and decodes them to float samples, stored in the [outputBuffer].
  /// Set [inputBufferIndex] to `0` to indicate packet loss.
  @override
  Float32List decodeFloat(
      {bool autoSoftClip = false, bool fec = false, int? loss}) {
    Pointer inputNative;
    int frameSize;
    if (inputBufferIndex > 0) {
      inputNative = _inputBuffer;
      frameSize = maxOutputBufferSizeBytes ~/ (4 * channels);
    } else {
      inputNative = nullptr;
      frameSize = _estimateLoss(loss, lastPacketDurationMs);
    }
    int outputSamplesPerChannel = opus.decoder.opus_decode_float(
        _opusDecoder,
        inputNative,
        inputBufferIndex,
        _outputBuffer.cast(),
        frameSize,
        fec ? 1 : 0);
    if (outputSamplesPerChannel >= opus_defines.OPUS_OK) {
      _lastPacketDurationMs =
          _packetDuration(outputSamplesPerChannel, channels, sampleRate);
      _outputBufferIndex = 4 * outputSamplesPerChannel * channels;
      if (autoSoftClip) {
        return pcmSoftClipOutputBuffer();
      } else {
        return outputBufferAsFloat32List;
      }
    } else {
      throw OpusException(outputSamplesPerChannel);
    }
  }

  @override
  void destroy() {
    if (!_destroyed) {
      _destroyed = true;
      opus.decoder.opus_decoder_destroy(_opusDecoder);
      opus.allocator.free(_inputBuffer);
      opus.allocator.free(_outputBuffer);
      opus.allocator.free(_softClipBuffer);
    }
  }

  /// Performs soft clipping on the [outputBuffer].
  Float32List pcmSoftClipOutputBuffer() {
    opus.decoder.opus_pcm_soft_clip(_outputBuffer.cast(),
        _outputBufferIndex ~/ (4 * channels), channels, _softClipBuffer);
    return outputBufferAsFloat32List;
  }
}

/// Abstract base class for opus decoders.
abstract class OpusDecoder {
  /// The sample rate in Hz for this decoder.
  int get sampleRate;

  /// Number of channels, must be 1 for mono or 2 for stereo.
  int get channels;

  /// Wheter this decoder was already destroyed by calling [destroy].
  bool get destroyed;

  /// The duration of the last decoded packet in ms or null if there was no packet yet.
  int? get lastPacketDurationMs;

  Int16List decode({bool fec = false, int? loss});
  Float32List decodeFloat({bool autoSoftClip, bool fec = false, int? loss});

  /// Destroys this decoder by releasing all native resources.
  void destroy();
}

int _estimateLoss(int? loss, int? lastPacketDurationMs) {
  if (loss != null) {
    return loss;
  } else if (lastPacketDurationMs != null) {
    return lastPacketDurationMs;
  } else {
    throw new StateError(
        'Tried to estimate the loss based on the last packets duration, but there was no last packet!\n'
        'This happend because you called a decode function with no input (null as input in SimpleOpusDecoder or 0 as inputBufferIndex in BufferedOpusDecoder), but failed to specify how many milliseconds were lost.\n'
        'And since there was no previous sucessfull decoded packet, the decoder could not estimate how many milliseconds are missing.');
  }
}
