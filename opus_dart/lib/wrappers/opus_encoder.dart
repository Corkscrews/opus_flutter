// Contains methods and structs from the opus_encoder group of opus.h.
// SHOULD be imported as opus_encoder.
//
// Vendored from https://github.com/EPNW/opus_dart
// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names

import '../src/proxy_ffi.dart' as ffi;

/// Opus encoder state.
final class OpusEncoder extends ffi.Opaque {}

typedef _opus_encoder_get_size_C = ffi.Int32 Function(
  ffi.Int32 channels,
);
typedef _opus_encoder_get_size_Dart = int Function(
  int channels,
);
typedef _opus_encoder_create_C = ffi.Pointer<OpusEncoder> Function(
  ffi.Int32 Fs,
  ffi.Int32 channels,
  ffi.Int32 application,
  ffi.Pointer<ffi.Int32> error,
);
typedef _opus_encoder_create_Dart = ffi.Pointer<OpusEncoder> Function(
  int Fs,
  int channels,
  int application,
  ffi.Pointer<ffi.Int32> error,
);
typedef _opus_encoder_init_C = ffi.Int32 Function(
  ffi.Pointer<OpusEncoder> st,
  ffi.Int32 Fs,
  ffi.Int32 channels,
  ffi.Int32 application,
);
typedef _opus_encoder_init_Dart = int Function(
  ffi.Pointer<OpusEncoder> st,
  int Fs,
  int channels,
  int application,
);
typedef _opus_encode_C = ffi.Int32 Function(
  ffi.Pointer<OpusEncoder> st,
  ffi.Pointer<ffi.Int16> pcm,
  ffi.Int32 frame_size,
  ffi.Pointer<ffi.Uint8> data,
  ffi.Int32 max_data_bytes,
);
typedef _opus_encode_Dart = int Function(
  ffi.Pointer<OpusEncoder> st,
  ffi.Pointer<ffi.Int16> pcm,
  int frame_size,
  ffi.Pointer<ffi.Uint8> data,
  int max_data_bytes,
);
typedef _opus_encode_float_C = ffi.Int32 Function(
  ffi.Pointer<OpusEncoder> st,
  ffi.Pointer<ffi.Float> pcm,
  ffi.Int32 frame_size,
  ffi.Pointer<ffi.Uint8> data,
  ffi.Int32 max_data_bytes,
);
typedef _opus_encode_float_Dart = int Function(
  ffi.Pointer<OpusEncoder> st,
  ffi.Pointer<ffi.Float> pcm,
  int frame_size,
  ffi.Pointer<ffi.Uint8> data,
  int max_data_bytes,
);
typedef _opus_encoder_destroy_C = ffi.Void Function(
  ffi.Pointer<OpusEncoder> st,
);
typedef _opus_encoder_destroy_Dart = void Function(
  ffi.Pointer<OpusEncoder> st,
);

abstract class OpusEncoderFunctions {
  int opus_encoder_get_size(int channels);
  ffi.Pointer<OpusEncoder> opus_encoder_create(
      int Fs, int channels, int application, ffi.Pointer<ffi.Int32> error);
  int opus_encoder_init(
      ffi.Pointer<OpusEncoder> st, int Fs, int channels, int application);
  int opus_encode(ffi.Pointer<OpusEncoder> st, ffi.Pointer<ffi.Int16> pcm,
      int frame_size, ffi.Pointer<ffi.Uint8> data, int max_data_bytes);
  int opus_encode_float(ffi.Pointer<OpusEncoder> st,
      ffi.Pointer<ffi.Float> pcm, int frame_size, ffi.Pointer<ffi.Uint8> data,
      int max_data_bytes);
  void opus_encoder_destroy(ffi.Pointer<OpusEncoder> st);
  int opus_encoder_ctl(ffi.Pointer<OpusEncoder> st, int request, int va);
}

class FunctionsAndGlobals implements OpusEncoderFunctions {
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  FunctionsAndGlobals(ffi.DynamicLibrary dynamicLibrary)
      : _opus_encoder_get_size = dynamicLibrary.lookupFunction<
            _opus_encoder_get_size_C, _opus_encoder_get_size_Dart>(
          'opus_encoder_get_size',
        ),
        _opus_encoder_create = dynamicLibrary
            .lookupFunction<_opus_encoder_create_C, _opus_encoder_create_Dart>(
          'opus_encoder_create',
        ),
        _opus_encoder_init = dynamicLibrary
            .lookupFunction<_opus_encoder_init_C, _opus_encoder_init_Dart>(
          'opus_encoder_init',
        ),
        _opus_encode =
            dynamicLibrary.lookupFunction<_opus_encode_C, _opus_encode_Dart>(
          'opus_encode',
        ),
        _opus_encode_float = dynamicLibrary
            .lookupFunction<_opus_encode_float_C, _opus_encode_float_Dart>(
          'opus_encode_float',
        ),
        _opus_encoder_destroy = dynamicLibrary.lookupFunction<
            _opus_encoder_destroy_C, _opus_encoder_destroy_Dart>(
          'opus_encoder_destroy',
        ),
        _lookup = dynamicLibrary.lookup;

  @override
  int opus_encoder_get_size(
    int channels,
  ) {
    return _opus_encoder_get_size(channels);
  }

  final _opus_encoder_get_size_Dart _opus_encoder_get_size;

  @override
  ffi.Pointer<OpusEncoder> opus_encoder_create(
    int Fs,
    int channels,
    int application,
    ffi.Pointer<ffi.Int32> error,
  ) {
    return _opus_encoder_create(Fs, channels, application, error);
  }

  final _opus_encoder_create_Dart _opus_encoder_create;

  @override
  int opus_encoder_init(
    ffi.Pointer<OpusEncoder> st,
    int Fs,
    int channels,
    int application,
  ) {
    return _opus_encoder_init(st, Fs, channels, application);
  }

  final _opus_encoder_init_Dart _opus_encoder_init;

  @override
  int opus_encode(
    ffi.Pointer<OpusEncoder> st,
    ffi.Pointer<ffi.Int16> pcm,
    int frame_size,
    ffi.Pointer<ffi.Uint8> data,
    int max_data_bytes,
  ) {
    return _opus_encode(st, pcm, frame_size, data, max_data_bytes);
  }

  final _opus_encode_Dart _opus_encode;

  @override
  int opus_encode_float(
    ffi.Pointer<OpusEncoder> st,
    ffi.Pointer<ffi.Float> pcm,
    int frame_size,
    ffi.Pointer<ffi.Uint8> data,
    int max_data_bytes,
  ) {
    return _opus_encode_float(st, pcm, frame_size, data, max_data_bytes);
  }

  final _opus_encode_float_Dart _opus_encode_float;

  @override
  void opus_encoder_destroy(
    ffi.Pointer<OpusEncoder> st,
  ) {
    _opus_encoder_destroy(st);
  }

  final _opus_encoder_destroy_Dart _opus_encoder_destroy;

  /// Perform a CTL function on an Opus encoder.
  ///
  /// Generally the request and subsequent arguments are generated
  /// by a convenience macro.
  ///
  /// [st] is the `OpusEncoder*` encoder state.
  /// [request] and all remaining parameters should be replaced by one
  /// of the convenience macros in `opus_genericctls` or
  /// `opus_encoderctls`.
  @override
  int opus_encoder_ctl(
    ffi.Pointer<OpusEncoder> st,
    int request,
    int va,
  ) {
    return _opus_encoder_ctl(
      st,
      request,
      va,
    );
  }

  late final _opus_encoder_ctlPtr = _lookup<
      ffi.NativeFunction<
          ffi.Int Function(
              ffi.Pointer<OpusEncoder>, ffi.Int, ffi.Int)>>('opus_encoder_ctl');
  late final _opus_encoder_ctl = _opus_encoder_ctlPtr
      .asFunction<int Function(ffi.Pointer<OpusEncoder>, int, int)>();
}
