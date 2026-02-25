import 'proxy_ffi.dart';
import 'dart:typed_data';
import '../wrappers/opus_decoder.dart' as opus_decoder;
import '../wrappers/opus_defines.dart' as opus_defines;
import 'opus_dart_misc.dart';

int _packetDuration(int samples, int channels, int sampleRate) =>
    ((1000 * samples) ~/ (channels)) ~/ sampleRate;

/// Allocates a temporary error pointer, calls `opus_decoder_create`, checks
/// the result, and frees the error pointer. Returns the decoder on success or
/// throws [OpusException] on failure.
Pointer<opus_decoder.OpusDecoder> _createOpusDecoder({
  required int sampleRate,
  required int channels,
}) {
  final error = opus.allocator.call<Int32>(1);
  try {
    final decoder =
        opus.decoder.opus_decoder_create(sampleRate, channels, error);
    if (error.value != opus_defines.OPUS_OK) {
      throw OpusException(error.value);
    }
    return decoder;
  } finally {
    opus.allocator.free(error);
  }
}

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
  Pointer<Float> nativePcm = opus.allocator.call<Float>(input.length);
  Pointer<Float>? nativeBuffer;
  try {
    nativePcm.asTypedList(input.length).setAll(0, input);
    nativeBuffer = opus.allocator.call<Float>(channels);
    opus.decoder.opus_pcm_soft_clip(
        nativePcm, input.length ~/ channels, channels, nativeBuffer);
    return Float32List.fromList(nativePcm.asTypedList(input.length));
  } finally {
    if (nativeBuffer != null) opus.allocator.free(nativeBuffer);
    opus.allocator.free(nativePcm);
  }
}

/// An easy to use implementation of [OpusDecoder].
/// Don't forget to call [destroy] once you are done with it.
///
/// All method calls in this class allocate their own memory everytime they are called.
/// See the [BufferedOpusDecoder] for an implementation with less allocation calls.
class SimpleOpusDecoder extends OpusDecoder {
  static final _finalizer = Finalizer<void Function()>((cleanup) => cleanup());

  final Pointer<opus_decoder.OpusDecoder> _opusDecoder;
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

  final Pointer<Float> _softClipBuffer;

  final int _maxSamplesPerPacket;

  SimpleOpusDecoder._(
      this._opusDecoder, this.sampleRate, this.channels, this._softClipBuffer)
      : _destroyed = false,
        _maxSamplesPerPacket = maxSamplesPerPacket(sampleRate, channels) {
    final decoder = _opusDecoder;
    final softClip = _softClipBuffer;
    _finalizer.attach(this, () {
      opus.decoder.opus_decoder_destroy(decoder);
      opus.allocator.free(softClip);
    }, detach: this);
  }

  /// Creates an new [SimpleOpusDecoder] based on the [sampleRate] and [channels].
  /// See the matching fields for more information about these parameters.
  factory SimpleOpusDecoder({required int sampleRate, required int channels}) {
    final softClipBuffer = opus.allocator.call<Float>(channels);
    try {
      final decoder =
          _createOpusDecoder(sampleRate: sampleRate, channels: channels);
      return SimpleOpusDecoder._(decoder, sampleRate, channels, softClipBuffer);
    } catch (_) {
      opus.allocator.free(softClipBuffer);
      rethrow;
    }
  }

  /// Allocates the input buffer if needed, computes frame size, invokes
  /// [nativeDecode], checks the result, updates duration tracking, and frees
  /// the input buffer. Returns the output sample count per channel.
  ///
  /// Callers are responsible for the destroyed check and for allocating/freeing
  /// the output buffer in their own try/finally scope.
  int _doDecode({
    required Uint8List? input,
    required bool fec,
    required int? loss,
    required int Function(Pointer<Uint8> inputPtr, int inputLen, int frameSize)
        nativeDecode,
  }) {
    Pointer<Uint8>? inputNative;
    try {
      if (input != null) {
        inputNative = opus.allocator.call<Uint8>(input.length);
        inputNative.asTypedList(input.length).setAll(0, input);
      }
      final frameSize = (input == null || fec)
          ? _estimateLoss(loss, lastPacketDurationMs)
          : _maxSamplesPerPacket;
      final outputSamplesPerChannel =
          nativeDecode(inputNative ?? nullptr, input?.length ?? 0, frameSize);
      if (outputSamplesPerChannel < opus_defines.OPUS_OK) {
        throw OpusException(outputSamplesPerChannel);
      }
      _lastPacketDurationMs =
          _packetDuration(outputSamplesPerChannel, channels, sampleRate);
      return outputSamplesPerChannel;
    } finally {
      if (inputNative != null) opus.allocator.free(inputNative);
    }
  }

  /// Decodes an opus packet to s16le samples, represented as [Int16List].
  /// Use `null` as [input] to indicate packet loss.
  ///
  /// On packet loss, the [loss] parameter needs to be exactly the duration
  /// of audio that is missing in milliseconds, otherwise the decoder will
  /// not be in the optimal state to decode the next incoming packet.
  /// If you don't know the duration, leave it `null` and [lastPacketDurationMs]
  /// will be used as an estimate instead.
  ///
  /// If you want to use forward error correction, don't report packet loss
  /// by calling this method with `null` as input (unless it is a real packet
  /// loss), but instead, wait for the next packet and call this method with
  /// the received packet, [fec] set to `true` and [loss] to the missing duration
  /// of the missing audio in ms (as above). Then, call this method a second time with
  /// the same packet, but with [fec] set to `false`. You can read more about the
  /// correct usage of forward error correction [here](https://stackoverflow.com/questions/49427579/how-to-use-fec-feature-for-opus-codec).
  /// Note: A real packet loss occurs if you lose two or more packets in a row.
  /// You are only able to restore the last lost packet and the other packets are
  /// really lost. So for them, you have to report packet loss.
  ///
  /// The input bytes need to represent a whole packet!
  @override
  Int16List decode({Uint8List? input, bool fec = false, int? loss}) {
    if (_destroyed) throw OpusDestroyedError.decoder();
    final outputNative = opus.allocator.call<Int16>(_maxSamplesPerPacket);
    try {
      final outputSamplesPerChannel = _doDecode(
        input: input,
        fec: fec,
        loss: loss,
        nativeDecode: (inputPtr, inputLen, frameSize) =>
            opus.decoder.opus_decode(_opusDecoder, inputPtr, inputLen,
                outputNative, frameSize, fec ? 1 : 0),
      );
      return Int16List.fromList(
          outputNative.asTypedList(outputSamplesPerChannel * channels));
    } finally {
      opus.allocator.free(outputNative);
    }
  }

  /// Decodes an opus packet to float samples, represented as [Float32List].
  /// Use `null` as [input] to indicate packet loss.
  ///
  /// If [autoSoftClip] is true, softcliping is applied to the output.
  /// This behaves just like  the top level [pcmSoftClip] function,
  /// but is more effective since it doesn't need to copy the samples,
  /// because they already are in the native buffer.
  ///
  /// Apart from that, this method behaves just as [decode], so see there for more information.
  @override
  Float32List decodeFloat(
      {Uint8List? input,
      bool fec = false,
      bool autoSoftClip = false,
      int? loss}) {
    if (_destroyed) throw OpusDestroyedError.decoder();
    final outputNative = opus.allocator.call<Float>(_maxSamplesPerPacket);
    try {
      final outputSamplesPerChannel = _doDecode(
        input: input,
        fec: fec,
        loss: loss,
        nativeDecode: (inputPtr, inputLen, frameSize) =>
            opus.decoder.opus_decode_float(_opusDecoder, inputPtr, inputLen,
                outputNative, frameSize, fec ? 1 : 0),
      );
      if (autoSoftClip) {
        opus.decoder.opus_pcm_soft_clip(outputNative,
            outputSamplesPerChannel ~/ channels, channels, _softClipBuffer);
      }
      return Float32List.fromList(
          outputNative.asTypedList(outputSamplesPerChannel * channels));
    } finally {
      opus.allocator.free(outputNative);
    }
  }

  @override
  void destroy() {
    if (!_destroyed) {
      _destroyed = true;
      opus.decoder.opus_decoder_destroy(_opusDecoder);
      opus.allocator.free(_softClipBuffer);
      _finalizer.detach(this);
    }
  }
}

/// An implementation of [OpusDecoder] that uses preallocated buffers.
/// Don't forget to call [destroy] once you are done with it.
///
/// The idea behind this implementation is to reduce the amount of memory allocation calls.
/// Instead of allocating new buffers everytime something is decoded, the buffers are
/// allocated at initialization. Then, an opus packet is directly written into the [inputBuffer],
/// the [inputBufferIndex] is updated, based on how many bytes where written, and
/// one of the decode methods is called. The decoded pcm samples can then be accessed using
/// the [outputBuffer] getter (or one of the [outputBufferAsInt16List] or [outputBufferAsFloat32List] convenience getters).
/// ```
/// BufferedOpusDecoder decoder;
///
/// void example() {
///   // Get an opus packet
///   Uint8List packet = receivePacket();
///   // Set the bytes to the input buffer
///   decoder.inputBuffer.setAll(0, packet);
///   // Update the inputBufferIndex with amount of bytes written
///   decoder.inputBufferIndex = packet.length;
///   // decode
///   decoder.decode();
///   // Interpret the output as s16le
///   Int16List pcm = decoder.outputBufferAsInt16List;
///   doSomething(pcm);
/// }
/// ```
class BufferedOpusDecoder extends OpusDecoder {
  static final _finalizer = Finalizer<void Function()>((cleanup) => cleanup());

  final Pointer<opus_decoder.OpusDecoder> _opusDecoder;
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
  /// Should be chosen big enough to hold a maximal opus packet
  /// with size of [maxDataBytes] bytes.
  final int maxInputBufferSizeBytes;

  /// Indicates, how many bytes of data are currently stored in the [inputBuffer].
  int inputBufferIndex;

  final Pointer<Uint8> _inputBuffer;

  /// Returns the native input buffer backed by native memory.
  ///
  /// You should write the opus packet you want to decode as bytes into this buffer,
  /// update the [inputBufferIndex] accordingly and call one of the decode methods.
  ///
  /// You must not put more bytes then [maxInputBufferSizeBytes] into this buffer.
  Uint8List get inputBuffer =>
      _inputBuffer.asTypedList(maxInputBufferSizeBytes);

  /// The size of the allocated the output buffer. If this value is chosen
  /// too small, this decoder will not be capable of decoding some packets.
  ///
  /// See the constructor for information, how to choose this.
  final int maxOutputBufferSizeBytes;
  int _outputBufferIndex;
  final Pointer<Uint8> _outputBuffer;

  /// The portion of the allocated output buffer that is currently filled with data.
  /// The data are pcm samples, either encoded as s16le or floats, depending on
  /// what method was used to decode the input packet.
  ///
  /// Returns a copy of the native output buffer. This is safe across WASM
  /// memory growth — the returned list remains valid even if subsequent
  /// allocations replace the underlying ArrayBuffer.
  Uint8List get outputBuffer =>
      Uint8List.fromList(_outputBuffer.asTypedList(_outputBufferIndex));

  /// Convenience method to get the current output buffer as s16le.
  /// Returns a copy safe across WASM memory growth.
  Int16List get outputBufferAsInt16List => Int16List.fromList(
      _outputBuffer.cast<Int16>().asTypedList(_outputBufferIndex ~/ bytesPerInt16Sample));

  /// Convenience method to get the current output buffer as floats.
  /// Returns a copy safe across WASM memory growth.
  Float32List get outputBufferAsFloat32List => Float32List.fromList(
      _outputBuffer.cast<Float>().asTypedList(_outputBufferIndex ~/ bytesPerFloatSample));

  final Pointer<Float> _softClipBuffer;

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
        _outputBufferIndex = 0 {
    final decoder = _opusDecoder;
    final input = _inputBuffer;
    final output = _outputBuffer;
    final softClip = _softClipBuffer;
    _finalizer.attach(this, () {
      opus.decoder.opus_decoder_destroy(decoder);
      opus.allocator.free(input);
      opus.allocator.free(output);
      opus.allocator.free(softClip);
    }, detach: this);
  }

  /// Creates an new [BufferedOpusDecoder] based on the [sampleRate] and [channels].
  /// The native allocated buffer size is determined by [maxInputBufferSizeBytes] and [maxOutputBufferSizeBytes].
  ///
  /// You should choose [maxInputBufferSizeBytes] big enough to put every opus packet you want to decode in it.
  /// If you omit this parameter, [maxDataBytes] is used, which guarantees that there is enough space for every
  /// valid opus packet.
  ///
  /// [maxOutputBufferSizeBytes] is the size of the output buffer, which will hold the decoded frames.
  /// If this value is chosen too small, this decoder will not be capable of decoding some packets.
  /// If you are unsure, just let it `null`, so the maximum size of resulting frames will be calculated
  /// Here is some more theory about that:
  /// A single opus packet may contain up to 120ms of audio, so assuming you are decoding
  /// packets with [sampleRate] and [channels] and want them stored as s16le (2 bytes per sample),
  /// then `maxOutputBufferSizeBytes = [sampleRate]~/1000 * 120 * channels * 2`.
  /// If you want your samples stored as floats (using the [decodeFloat] method), you need to
  /// multiply by `4` instead of `2` (since a float takes 4 bytes per value).
  /// If you know the frame time in advance, you can use the above formula to choose a smaller value.
  /// Also note that there is a [maxSamplesPerPacket] function.
  ///
  /// For the other parameters, see the matching fields for more information.
  factory BufferedOpusDecoder(
      {required int sampleRate,
      required int channels,
      int? maxInputBufferSizeBytes,
      int? maxOutputBufferSizeBytes}) {
    maxInputBufferSizeBytes ??= maxDataBytes;
    maxOutputBufferSizeBytes ??= bytesPerFloatSample * maxSamplesPerPacket(sampleRate, channels);
    final input = opus.allocator.call<Uint8>(maxInputBufferSizeBytes);
    Pointer<Uint8>? output;
    Pointer<Float>? softClipBuffer;
    try {
      output = opus.allocator.call<Uint8>(maxOutputBufferSizeBytes);
      softClipBuffer = opus.allocator.call<Float>(channels);
      final decoder =
          _createOpusDecoder(sampleRate: sampleRate, channels: channels);
      return BufferedOpusDecoder._(
          decoder,
          sampleRate,
          channels,
          input,
          maxInputBufferSizeBytes,
          output,
          maxOutputBufferSizeBytes,
          softClipBuffer);
    } catch (_) {
      if (softClipBuffer != null) opus.allocator.free(softClipBuffer);
      if (output != null) opus.allocator.free(output);
      opus.allocator.free(input);
      rethrow;
    }
  }

  /// Computes the input pointer and frame size from [inputBufferIndex],
  /// invokes the appropriate native decode function, checks the result,
  /// and updates duration tracking and output buffer index.
  void _decodeBuffer(
      {required bool useFloat, required bool fec, required int? loss}) {
    if (_destroyed) throw OpusDestroyedError.decoder();
    final bytesPerSample =
        useFloat ? bytesPerFloatSample : bytesPerInt16Sample;
    Pointer<Uint8> inputNative;
    int frameSize;
    if (inputBufferIndex > 0) {
      inputNative = _inputBuffer;
      frameSize = maxOutputBufferSizeBytes ~/ (bytesPerSample * channels);
    } else {
      inputNative = nullptr;
      frameSize = _estimateLoss(loss, lastPacketDurationMs);
    }
    final outputSamplesPerChannel = useFloat
        ? opus.decoder.opus_decode_float(_opusDecoder, inputNative,
            inputBufferIndex, _outputBuffer.cast<Float>(), frameSize,
            fec ? 1 : 0)
        : opus.decoder.opus_decode(_opusDecoder, inputNative, inputBufferIndex,
            _outputBuffer.cast<Int16>(), frameSize, fec ? 1 : 0);
    if (outputSamplesPerChannel < opus_defines.OPUS_OK) {
      throw OpusException(outputSamplesPerChannel);
    }
    _lastPacketDurationMs =
        _packetDuration(outputSamplesPerChannel, channels, sampleRate);
    _outputBufferIndex = bytesPerSample * outputSamplesPerChannel * channels;
  }

  /// Interpretes [inputBufferIndex] bytes from the [inputBuffer] as a whole
  /// opus packet and decodes them to s16le samples, stored in the [outputBuffer].
  /// Set [inputBufferIndex] to `0` to indicate packet loss.
  ///
  /// On packet loss, the [loss] parameter needs to be exactly the duration
  /// of audio that is missing in milliseconds, otherwise the decoder will
  /// not be in the optimal state to decode the next incoming packet.
  /// If you don't know the duration, leave it `null` and [lastPacketDurationMs]
  /// will be used as an estimate instead.
  ///
  /// If you want to use forward error correction, don't report packet loss
  /// by setting the [inputBufferIndex] to `0` (unless it is a real packet
  /// loss), but instead, wait for the next packet and write this to the [inputBuffer],
  /// with [inputBufferIndex] set accordingly. Then call this method with
  /// [fec] set to `true` and [loss] to the missing duration of the missing audio
  /// in ms (as above). Then, call this method a second time with
  /// the same packet, but with [fec] set to `false`. You can read more about the
  /// correct usage of forward error correction [here](https://stackoverflow.com/questions/49427579/how-to-use-fec-feature-for-opus-codec).
  /// Note: A real packet loss occurs if you lose two or more packets in a row.
  /// You are only able to restore the last lost packet and the other packets are
  /// really lost. So for them, you have to report packet loss.
  ///
  /// The input bytes need to represent a whole packet!
  ///
  /// The returned list is actually just the [outputBufferAsInt16List].
  @override
  Int16List decode({bool fec = false, int? loss}) {
    _decodeBuffer(useFloat: false, fec: fec, loss: loss);
    return outputBufferAsInt16List;
  }

  /// Interpretes [inputBufferIndex] bytes from the [inputBuffer] as a whole
  /// opus packet and decodes them to float samples, stored in the [outputBuffer].
  /// Set [inputBufferIndex] to `0` to indicate packet loss.
  ///
  /// If [autoSoftClip] is true, this decoder's [pcmSoftClipOutputBuffer] method is automatically called.
  ///
  /// Apart from that, this method behaves just as [decode], so see there for more information.
  @override
  Float32List decodeFloat(
      {bool autoSoftClip = false, bool fec = false, int? loss}) {
    _decodeBuffer(useFloat: true, fec: fec, loss: loss);
    if (autoSoftClip) {
      return pcmSoftClipOutputBuffer();
    }
    return outputBufferAsFloat32List;
  }

  @override
  void destroy() {
    if (!_destroyed) {
      _destroyed = true;
      opus.decoder.opus_decoder_destroy(_opusDecoder);
      opus.allocator.free(_inputBuffer);
      opus.allocator.free(_outputBuffer);
      opus.allocator.free(_softClipBuffer);
      _finalizer.detach(this);
    }
  }

  /// Performs soft clipping on the [outputBuffer].
  ///
  /// Behaves like the toplevel [pcmSoftClip] function, but without unnecessary copying.
  Float32List pcmSoftClipOutputBuffer() {
    if (_destroyed) throw OpusDestroyedError.decoder();
    opus.decoder.opus_pcm_soft_clip(_outputBuffer.cast<Float>(),
        _outputBufferIndex ~/ (bytesPerFloatSample * channels), channels, _softClipBuffer);
    return outputBufferAsFloat32List;
  }
}

/// Abstract base class for opus decoders.
abstract class OpusDecoder {
  /// The sample rate in Hz for this decoder.
  /// Opus supports sample rates from 8kHz to 48kHz so this value must be between 8000 and 48000.
  int get sampleRate;

  /// Number of channels, must be 1 for mono or 2 for stereo.
  int get channels;

  /// Whether this decoder was already destroyed by calling [destroy].
  /// If so, calling any method will result in an [OpusDestroyedError].
  bool get destroyed;

  /// The duration of the last decoded packet in ms or null if there was no packet yet.
  int? get lastPacketDurationMs;

  Int16List decode({bool fec = false, int? loss});
  Float32List decodeFloat({bool autoSoftClip, bool fec = false, int? loss});

  /// Destroys this decoder by releasing all native resources.
  /// After this, it is no longer possible to decode using this decoder, so any further method call will throw an [OpusDestroyedError].
  void destroy();
}

int _estimateLoss(int? loss, int? lastPacketDurationMs) {
  if (loss != null) return loss;
  if (lastPacketDurationMs != null) return lastPacketDurationMs;
  throw StateError(
      'Tried to estimate the loss based on the last packets duration, but there was no last packet!\n'
      'This happend because you called a decode function with no input (null as input in SimpleOpusDecoder or 0 as inputBufferIndex in BufferedOpusDecoder), but failed to specify how many milliseconds were lost.\n'
      'And since there was no previous successful decoded packet, the decoder could not estimate how many milliseconds are missing.');
}
