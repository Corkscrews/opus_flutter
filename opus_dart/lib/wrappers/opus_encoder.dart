/// Contains methods and structs from the opus_encoder group of opus.h.
/// SHOULD be imported as opus_encoder.
///
/// AUTOMATICALLY GENERATED FILE. DO NOT MODIFY.
// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names

// We are going to ignore subtype_of_sealed_class since dart analysis does not
// get the imports right when differentiating between web_ffi and dart:ffi
// ignore_for_file: subtype_of_sealed_class
library opus_encoder;

import '../src/proxy_ffi.dart' as ffi;

/// Opus encoder state.
class OpusEncoder extends ffi.Opaque {}

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

class FunctionsAndGlobals {
  FunctionsAndGlobals(ffi.DynamicLibrary _dynamicLibrary)
      : _opus_encoder_get_size = _dynamicLibrary.lookupFunction<
            _opus_encoder_get_size_C, _opus_encoder_get_size_Dart>(
          'opus_encoder_get_size',
        ),
        _opus_encoder_create = _dynamicLibrary
            .lookupFunction<_opus_encoder_create_C, _opus_encoder_create_Dart>(
          'opus_encoder_create',
        ),
        _opus_encoder_init = _dynamicLibrary
            .lookupFunction<_opus_encoder_init_C, _opus_encoder_init_Dart>(
          'opus_encoder_init',
        ),
        _opus_encode =
            _dynamicLibrary.lookupFunction<_opus_encode_C, _opus_encode_Dart>(
          'opus_encode',
        ),
        _opus_encode_float = _dynamicLibrary
            .lookupFunction<_opus_encode_float_C, _opus_encode_float_Dart>(
          'opus_encode_float',
        ),
        _opus_encoder_destroy = _dynamicLibrary.lookupFunction<
            _opus_encoder_destroy_C, _opus_encoder_destroy_Dart>(
          'opus_encoder_destroy',
        );

  int opus_encoder_get_size(
    int channels,
  ) {
    return _opus_encoder_get_size(channels);
  }

  final _opus_encoder_get_size_Dart _opus_encoder_get_size;

  ffi.Pointer<OpusEncoder> opus_encoder_create(
    int Fs,
    int channels,
    int application,
    ffi.Pointer<ffi.Int32> error,
  ) {
    return _opus_encoder_create(Fs, channels, application, error);
  }

  final _opus_encoder_create_Dart _opus_encoder_create;

  int opus_encoder_init(
    ffi.Pointer<OpusEncoder> st,
    int Fs,
    int channels,
    int application,
  ) {
    return _opus_encoder_init(st, Fs, channels, application);
  }

  final _opus_encoder_init_Dart _opus_encoder_init;

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

  void opus_encoder_destroy(
    ffi.Pointer<OpusEncoder> st,
  ) {
    _opus_encoder_destroy(st);
  }

  final _opus_encoder_destroy_Dart _opus_encoder_destroy;
}
