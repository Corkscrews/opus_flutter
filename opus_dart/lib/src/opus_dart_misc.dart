import 'dart:convert';

import 'proxy_ffi.dart';

import '../wrappers/opus_libinfo.dart' as opus_libinfo;
import '../wrappers/opus_encoder.dart' as opus_encoder;
import '../wrappers/opus_decoder.dart' as opus_decoder;

/// Max bitstream size of a single opus packet.
///
/// See [here](https://stackoverflow.com/questions/55698317/what-value-to-use-for-libopus-encoder-max-data-bytes-field)
/// for an explanation how this was calculated.
const int maxDataBytes = 3 * 1275;

/// Calculates, how much sampels a single opus package at [sampleRate] with [channels] may contain.
///
/// A single package may contain up 120ms of audio. This value is reached by combining up to 3 frames of 40ms audio.
int maxSamplesPerPacket(int sampleRate, int channels) =>
    ((sampleRate * channels * 120) / 1000).ceil();

/// Returns the version of the native libopus library.
String getOpusVersion() {
  return _asString(opus.libinfo.opus_get_version_string());
}

String _asString(Pointer<Uint8> pointer) {
  int i = 0;
  while (pointer[i] != 0) {
    i++;
  }
  return utf8.decode(pointer.asTypedList(i));
}

/// Thrown when a native exception occurs.
class OpusException implements Exception {
  final int errorCode;
  const OpusException(this.errorCode);
  @override
  String toString() {
    String error = _asString(opus.libinfo.opus_strerror(errorCode));
    return 'OpusException $errorCode: $error';
  }
}

/// Thrown when attempting to call an method on an already destroyed encoder or decoder.
class OpusDestroyedError extends StateError {
  OpusDestroyedError.encoder()
      : super(
            'OpusDestroyedException: This OpusEncoder was already destroyed!');
  OpusDestroyedError.decoder()
      : super(
            'OpusDestroyedException: This OpusDecoder was already destroyed!');
}

late ApiObject opus;

class ApiObject {
  final opus_libinfo.OpusLibInfoFunctions libinfo;
  final opus_encoder.OpusEncoderFunctions encoder;
  final opus_decoder.OpusDecoderFunctions decoder;
  final Allocator allocator;

  // coverage:ignore-start
  ApiObject(DynamicLibrary lib, this.allocator)
      : libinfo = opus_libinfo.FunctionsAndGlobals(lib),
        encoder = opus_encoder.FunctionsAndGlobals(lib),
        decoder = opus_decoder.FunctionsAndGlobals(lib);
  // coverage:ignore-end

  ApiObject.test({
    required this.libinfo,
    required this.encoder,
    required this.decoder,
    required this.allocator,
  });
}

/// Must be called to initialize this library.
///
/// [opusLib] must be a `DynamicLibrary` pointing to a native libopus binary.
/// It accepts [Object] so callers don't need to cast from the platform
/// interface's `Future<Object>` return type -- on native platforms this is a
/// `dart:ffi` DynamicLibrary, on web a `wasm_ffi` DynamicLibrary.
// coverage:ignore-start
void initOpus(Object opusLib) {
  opus = createApiObject(opusLib);
}
// coverage:ignore-end
