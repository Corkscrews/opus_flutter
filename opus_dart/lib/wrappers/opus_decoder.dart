/// Contains methods and structs from the opus_decoder group of opus.h.
/// SHOULD be imported as opus_decoder.
///
/// Vendored from https://github.com/EPNW/opus_dart
// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names

library opus_decoder;

import '../src/proxy_ffi.dart' as ffi;

/// Opus decoder state.
final class OpusDecoder extends ffi.Opaque {}

typedef _opus_decoder_get_size_C = ffi.Int32 Function(
  ffi.Int32 channels,
);
typedef _opus_decoder_get_size_Dart = int Function(
  int channels,
);
typedef _opus_decoder_create_C = ffi.Pointer<OpusDecoder> Function(
  ffi.Int32 Fs,
  ffi.Int32 channels,
  ffi.Pointer<ffi.Int32> error,
);
typedef _opus_decoder_create_Dart = ffi.Pointer<OpusDecoder> Function(
  int Fs,
  int channels,
  ffi.Pointer<ffi.Int32> error,
);
typedef _opus_decoder_init_C = ffi.Int32 Function(
  ffi.Pointer<OpusDecoder> st,
  ffi.Int32 Fs,
  ffi.Int32 channels,
);
typedef _opus_decoder_init_Dart = int Function(
  ffi.Pointer<OpusDecoder> st,
  int Fs,
  int channels,
);
typedef _opus_decode_C = ffi.Int32 Function(
  ffi.Pointer<OpusDecoder> st,
  ffi.Pointer<ffi.Uint8> data,
  ffi.Int32 len,
  ffi.Pointer<ffi.Int16> pcm,
  ffi.Int32 frame_size,
  ffi.Int32 decode_fec,
);
typedef _opus_decode_Dart = int Function(
  ffi.Pointer<OpusDecoder> st,
  ffi.Pointer<ffi.Uint8> data,
  int len,
  ffi.Pointer<ffi.Int16> pcm,
  int frame_size,
  int decode_fec,
);
typedef _opus_decode_float_C = ffi.Int32 Function(
  ffi.Pointer<OpusDecoder> st,
  ffi.Pointer<ffi.Uint8> data,
  ffi.Int32 len,
  ffi.Pointer<ffi.Float> pcm,
  ffi.Int32 frame_size,
  ffi.Int32 decode_fec,
);
typedef _opus_decode_float_Dart = int Function(
  ffi.Pointer<OpusDecoder> st,
  ffi.Pointer<ffi.Uint8> data,
  int len,
  ffi.Pointer<ffi.Float> pcm,
  int frame_size,
  int decode_fec,
);
typedef _opus_decoder_destroy_C = ffi.Void Function(
  ffi.Pointer<OpusDecoder> st,
);
typedef _opus_decoder_destroy_Dart = void Function(
  ffi.Pointer<OpusDecoder> st,
);
typedef _opus_packet_parse_C = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8> data,
  ffi.Int32 len,
  ffi.Pointer<ffi.Uint8> out_toc,
  ffi.Pointer<ffi.Uint8> frames,
  ffi.Int16 size,
  ffi.Pointer<ffi.Int32> payload_offset,
);
typedef _opus_packet_parse_Dart = int Function(
  ffi.Pointer<ffi.Uint8> data,
  int len,
  ffi.Pointer<ffi.Uint8> out_toc,
  ffi.Pointer<ffi.Uint8> frames,
  int size,
  ffi.Pointer<ffi.Int32> payload_offset,
);
typedef _opus_packet_get_bandwidth_C = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8> data,
);
typedef _opus_packet_get_bandwidth_Dart = int Function(
  ffi.Pointer<ffi.Uint8> data,
);
typedef _opus_packet_get_samples_per_frame_C = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8> data,
  ffi.Int32 Fs,
);
typedef _opus_packet_get_samples_per_frame_Dart = int Function(
  ffi.Pointer<ffi.Uint8> data,
  int Fs,
);
typedef _opus_packet_get_nb_channels_C = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8> data,
);
typedef _opus_packet_get_nb_channels_Dart = int Function(
  ffi.Pointer<ffi.Uint8> data,
);
typedef _opus_packet_get_nb_frames_C = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8> packet,
  ffi.Int32 len,
);
typedef _opus_packet_get_nb_frames_Dart = int Function(
  ffi.Pointer<ffi.Uint8> packet,
  int len,
);
typedef _opus_packet_get_nb_samples_C = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8> packet,
  ffi.Int32 len,
  ffi.Int32 Fs,
);
typedef _opus_packet_get_nb_samples_Dart = int Function(
  ffi.Pointer<ffi.Uint8> packet,
  int len,
  int Fs,
);
typedef _opus_decoder_get_nb_samples_C = ffi.Int32 Function(
  ffi.Pointer<OpusDecoder> dec,
  ffi.Pointer<ffi.Uint8> packet,
  ffi.Int32 len,
);
typedef _opus_decoder_get_nb_samples_Dart = int Function(
  ffi.Pointer<OpusDecoder> dec,
  ffi.Pointer<ffi.Uint8> packet,
  int len,
);
typedef _opus_pcm_soft_clip_C = ffi.Void Function(
  ffi.Pointer<ffi.Float> pcm,
  ffi.Int32 frame_size,
  ffi.Int32 channels,
  ffi.Pointer<ffi.Float> softclip_mem,
);
typedef _opus_pcm_soft_clip_Dart = void Function(
  ffi.Pointer<ffi.Float> pcm,
  int frame_size,
  int channels,
  ffi.Pointer<ffi.Float> softclip_mem,
);

class FunctionsAndGlobals {
  FunctionsAndGlobals(ffi.DynamicLibrary _dynamicLibrary)
      : _opus_decoder_get_size = _dynamicLibrary.lookupFunction<
            _opus_decoder_get_size_C, _opus_decoder_get_size_Dart>(
          'opus_decoder_get_size',
        ),
        _opus_decoder_create = _dynamicLibrary
            .lookupFunction<_opus_decoder_create_C, _opus_decoder_create_Dart>(
          'opus_decoder_create',
        ),
        _opus_decoder_init = _dynamicLibrary
            .lookupFunction<_opus_decoder_init_C, _opus_decoder_init_Dart>(
          'opus_decoder_init',
        ),
        _opus_decode =
            _dynamicLibrary.lookupFunction<_opus_decode_C, _opus_decode_Dart>(
          'opus_decode',
        ),
        _opus_decode_float = _dynamicLibrary
            .lookupFunction<_opus_decode_float_C, _opus_decode_float_Dart>(
          'opus_decode_float',
        ),
        _opus_decoder_destroy = _dynamicLibrary.lookupFunction<
            _opus_decoder_destroy_C, _opus_decoder_destroy_Dart>(
          'opus_decoder_destroy',
        ),
        _opus_packet_parse = _dynamicLibrary
            .lookupFunction<_opus_packet_parse_C, _opus_packet_parse_Dart>(
          'opus_packet_parse',
        ),
        _opus_packet_get_bandwidth = _dynamicLibrary.lookupFunction<
            _opus_packet_get_bandwidth_C, _opus_packet_get_bandwidth_Dart>(
          'opus_packet_get_bandwidth',
        ),
        _opus_packet_get_samples_per_frame = _dynamicLibrary.lookupFunction<
            _opus_packet_get_samples_per_frame_C,
            _opus_packet_get_samples_per_frame_Dart>(
          'opus_packet_get_samples_per_frame',
        ),
        _opus_packet_get_nb_channels = _dynamicLibrary.lookupFunction<
            _opus_packet_get_nb_channels_C, _opus_packet_get_nb_channels_Dart>(
          'opus_packet_get_nb_channels',
        ),
        _opus_packet_get_nb_frames = _dynamicLibrary.lookupFunction<
            _opus_packet_get_nb_frames_C, _opus_packet_get_nb_frames_Dart>(
          'opus_packet_get_nb_frames',
        ),
        _opus_packet_get_nb_samples = _dynamicLibrary.lookupFunction<
            _opus_packet_get_nb_samples_C, _opus_packet_get_nb_samples_Dart>(
          'opus_packet_get_nb_samples',
        ),
        _opus_decoder_get_nb_samples = _dynamicLibrary.lookupFunction<
            _opus_decoder_get_nb_samples_C, _opus_decoder_get_nb_samples_Dart>(
          'opus_decoder_get_nb_samples',
        ),
        _opus_pcm_soft_clip = _dynamicLibrary
            .lookupFunction<_opus_pcm_soft_clip_C, _opus_pcm_soft_clip_Dart>(
          'opus_pcm_soft_clip',
        );

  int opus_decoder_get_size(int channels) {
    return _opus_decoder_get_size(channels);
  }

  final _opus_decoder_get_size_Dart _opus_decoder_get_size;

  ffi.Pointer<OpusDecoder> opus_decoder_create(
    int Fs,
    int channels,
    ffi.Pointer<ffi.Int32> error,
  ) {
    return _opus_decoder_create(Fs, channels, error);
  }

  final _opus_decoder_create_Dart _opus_decoder_create;

  int opus_decoder_init(
    ffi.Pointer<OpusDecoder> st,
    int Fs,
    int channels,
  ) {
    return _opus_decoder_init(st, Fs, channels);
  }

  final _opus_decoder_init_Dart _opus_decoder_init;

  int opus_decode(
    ffi.Pointer<OpusDecoder> st,
    ffi.Pointer<ffi.Uint8> data,
    int len,
    ffi.Pointer<ffi.Int16> pcm,
    int frame_size,
    int decode_fec,
  ) {
    return _opus_decode(st, data, len, pcm, frame_size, decode_fec);
  }

  final _opus_decode_Dart _opus_decode;

  int opus_decode_float(
    ffi.Pointer<OpusDecoder> st,
    ffi.Pointer<ffi.Uint8> data,
    int len,
    ffi.Pointer<ffi.Float> pcm,
    int frame_size,
    int decode_fec,
  ) {
    return _opus_decode_float(st, data, len, pcm, frame_size, decode_fec);
  }

  final _opus_decode_float_Dart _opus_decode_float;

  void opus_decoder_destroy(ffi.Pointer<OpusDecoder> st) {
    _opus_decoder_destroy(st);
  }

  final _opus_decoder_destroy_Dart _opus_decoder_destroy;

  int opus_packet_parse(
    ffi.Pointer<ffi.Uint8> data,
    int len,
    ffi.Pointer<ffi.Uint8> out_toc,
    ffi.Pointer<ffi.Uint8> frames,
    int size,
    ffi.Pointer<ffi.Int32> payload_offset,
  ) {
    return _opus_packet_parse(data, len, out_toc, frames, size, payload_offset);
  }

  final _opus_packet_parse_Dart _opus_packet_parse;

  int opus_packet_get_bandwidth(ffi.Pointer<ffi.Uint8> data) {
    return _opus_packet_get_bandwidth(data);
  }

  final _opus_packet_get_bandwidth_Dart _opus_packet_get_bandwidth;

  int opus_packet_get_samples_per_frame(
    ffi.Pointer<ffi.Uint8> data,
    int Fs,
  ) {
    return _opus_packet_get_samples_per_frame(data, Fs);
  }

  final _opus_packet_get_samples_per_frame_Dart
      _opus_packet_get_samples_per_frame;

  int opus_packet_get_nb_channels(ffi.Pointer<ffi.Uint8> data) {
    return _opus_packet_get_nb_channels(data);
  }

  final _opus_packet_get_nb_channels_Dart _opus_packet_get_nb_channels;

  int opus_packet_get_nb_frames(
    ffi.Pointer<ffi.Uint8> packet,
    int len,
  ) {
    return _opus_packet_get_nb_frames(packet, len);
  }

  final _opus_packet_get_nb_frames_Dart _opus_packet_get_nb_frames;

  int opus_packet_get_nb_samples(
    ffi.Pointer<ffi.Uint8> packet,
    int len,
    int Fs,
  ) {
    return _opus_packet_get_nb_samples(packet, len, Fs);
  }

  final _opus_packet_get_nb_samples_Dart _opus_packet_get_nb_samples;

  int opus_decoder_get_nb_samples(
    ffi.Pointer<OpusDecoder> dec,
    ffi.Pointer<ffi.Uint8> packet,
    int len,
  ) {
    return _opus_decoder_get_nb_samples(dec, packet, len);
  }

  final _opus_decoder_get_nb_samples_Dart _opus_decoder_get_nb_samples;

  void opus_pcm_soft_clip(
    ffi.Pointer<ffi.Float> pcm,
    int frame_size,
    int channels,
    ffi.Pointer<ffi.Float> softclip_mem,
  ) {
    _opus_pcm_soft_clip(pcm, frame_size, channels, softclip_mem);
  }

  final _opus_pcm_soft_clip_Dart _opus_pcm_soft_clip;
}
