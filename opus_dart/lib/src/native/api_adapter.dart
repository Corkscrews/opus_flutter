// Native implementations of the wrapper interfaces. Each method forwards to
// the generated declarations in opus_bindings.dart, so the codec classes run
// unchanged on the code asset and on the mock functions used in tests.
//
// The generated bindings use C's own types (char, unsigned char, int and
// their own opaque structs); the wrapper interfaces use Uint8, Int32 and the
// wrapper's opaque structs. The casts below are between types of the same
// size on every supported target.
// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';

import '../../wrappers/opus_decoder.dart';
import '../../wrappers/opus_encoder.dart';
import '../../wrappers/opus_libinfo.dart';
import 'opus_bindings.dart' as c;

final class NativeOpusLibInfo implements OpusLibInfoFunctions {
  const NativeOpusLibInfo();

  @override
  Pointer<Uint8> opus_get_version_string() =>
      c.opus_get_version_string().cast();

  @override
  Pointer<Uint8> opus_strerror(int error) => c.opus_strerror(error).cast();
}

final class NativeOpusEncoder implements OpusEncoderFunctions {
  const NativeOpusEncoder();

  @override
  int opus_encoder_get_size(int channels) => c.opus_encoder_get_size(channels);

  @override
  Pointer<OpusEncoder> opus_encoder_create(
    int Fs,
    int channels,
    int application,
    Pointer<Int32> error,
  ) => c.opus_encoder_create(Fs, channels, application, error.cast()).cast();

  @override
  int opus_encoder_init(
    Pointer<OpusEncoder> st,
    int Fs,
    int channels,
    int application,
  ) => c.opus_encoder_init(st.cast(), Fs, channels, application);

  @override
  int opus_encode(
    Pointer<OpusEncoder> st,
    Pointer<Int16> pcm,
    int frame_size,
    Pointer<Uint8> data,
    int max_data_bytes,
  ) => c.opus_encode(st.cast(), pcm, frame_size, data.cast(), max_data_bytes);

  @override
  int opus_encode_float(
    Pointer<OpusEncoder> st,
    Pointer<Float> pcm,
    int frame_size,
    Pointer<Uint8> data,
    int max_data_bytes,
  ) => c.opus_encode_float(
    st.cast(),
    pcm,
    frame_size,
    data.cast(),
    max_data_bytes,
  );

  @override
  void opus_encoder_destroy(Pointer<OpusEncoder> st) =>
      c.opus_encoder_destroy(st.cast());

  @override
  int opus_encoder_ctl(Pointer<OpusEncoder> st, int request, int va) =>
      c.opus_codec_encoder_ctl_int(st.cast(), request, va);
}

final class NativeOpusDecoder implements OpusDecoderFunctions {
  const NativeOpusDecoder();

  @override
  int opus_decoder_get_size(int channels) => c.opus_decoder_get_size(channels);

  @override
  Pointer<OpusDecoder> opus_decoder_create(
    int Fs,
    int channels,
    Pointer<Int32> error,
  ) => c.opus_decoder_create(Fs, channels, error.cast()).cast();

  @override
  int opus_decoder_init(Pointer<OpusDecoder> st, int Fs, int channels) =>
      c.opus_decoder_init(st.cast(), Fs, channels);

  @override
  int opus_decode(
    Pointer<OpusDecoder> st,
    Pointer<Uint8> data,
    int len,
    Pointer<Int16> pcm,
    int frame_size,
    int decode_fec,
  ) => c.opus_decode(st.cast(), data.cast(), len, pcm, frame_size, decode_fec);

  @override
  int opus_decode_float(
    Pointer<OpusDecoder> st,
    Pointer<Uint8> data,
    int len,
    Pointer<Float> pcm,
    int frame_size,
    int decode_fec,
  ) => c.opus_decode_float(
    st.cast(),
    data.cast(),
    len,
    pcm,
    frame_size,
    decode_fec,
  );

  @override
  void opus_decoder_destroy(Pointer<OpusDecoder> st) =>
      c.opus_decoder_destroy(st.cast());

  @override
  int opus_packet_parse(
    Pointer<Uint8> data,
    int len,
    Pointer<Uint8> out_toc,
    Pointer<Pointer<Uint8>> frames,
    Pointer<Int16> size,
    Pointer<Int32> payload_offset,
  ) => c.opus_packet_parse(
    data.cast(),
    len,
    out_toc.cast(),
    frames.cast(),
    size,
    payload_offset.cast(),
  );

  @override
  int opus_packet_get_bandwidth(Pointer<Uint8> data) =>
      c.opus_packet_get_bandwidth(data.cast());

  @override
  int opus_packet_get_samples_per_frame(Pointer<Uint8> data, int Fs) =>
      c.opus_packet_get_samples_per_frame(data.cast(), Fs);

  @override
  int opus_packet_get_nb_channels(Pointer<Uint8> data) =>
      c.opus_packet_get_nb_channels(data.cast());

  @override
  int opus_packet_get_nb_frames(Pointer<Uint8> packet, int len) =>
      c.opus_packet_get_nb_frames(packet.cast(), len);

  @override
  int opus_packet_get_nb_samples(Pointer<Uint8> packet, int len, int Fs) =>
      c.opus_packet_get_nb_samples(packet.cast(), len, Fs);

  @override
  int opus_decoder_get_nb_samples(
    Pointer<OpusDecoder> dec,
    Pointer<Uint8> packet,
    int len,
  ) => c.opus_decoder_get_nb_samples(dec.cast(), packet.cast(), len);

  @override
  void opus_pcm_soft_clip(
    Pointer<Float> pcm,
    int frame_size,
    int channels,
    Pointer<Float> softclip_mem,
  ) => c.opus_pcm_soft_clip(pcm, frame_size, channels, softclip_mem);
}
