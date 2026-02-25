import 'proxy_ffi.dart';
import 'dart:typed_data';
import '../wrappers/opus_defines.dart' as opus_defines;
import 'opus_dart_misc.dart';

/// Bundles utility functions to examine opus packets.
///
/// All methods copy the input data into native memory.
abstract class OpusPacketUtils {
  static int _withNativePacket(
      Uint8List packet, int Function(Pointer<Uint8> data) operation) {
    Pointer<Uint8> data = opus.allocator.call<Uint8>(packet.length);
    data.asTypedList(packet.length).setAll(0, packet);
    try {
      int result = operation(data);
      if (result < opus_defines.OPUS_OK) {
        throw OpusException(result);
      }
      return result;
    } finally {
      opus.allocator.free(data);
    }
  }

  /// Returns the amount of samples in a [packet] given a [sampleRate].
  static int getSampleCount(
      {required Uint8List packet, required int sampleRate}) {
    return _withNativePacket(
        packet,
        (data) => opus.decoder
            .opus_packet_get_nb_samples(data, packet.length, sampleRate));
  }

  /// Returns the amount of frames in a [packet].
  static int getFrameCount({required Uint8List packet}) {
    return _withNativePacket(packet,
        (data) => opus.decoder.opus_packet_get_nb_frames(data, packet.length));
  }

  /// Returns the amount of samples per frame in a [packet] given a [sampleRate].
  static int getSamplesPerFrame(
      {required Uint8List packet, required int sampleRate}) {
    return _withNativePacket(
        packet,
        (data) =>
            opus.decoder.opus_packet_get_samples_per_frame(data, sampleRate));
  }

  /// Returns the channel count from a [packet]
  static int getChannelCount({required Uint8List packet}) {
    return _withNativePacket(
        packet, (data) => opus.decoder.opus_packet_get_nb_channels(data));
  }

  /// Returns the bandwidth from a [packet]
  static int getBandwidth({required Uint8List packet}) {
    return _withNativePacket(
        packet, (data) => opus.decoder.opus_packet_get_bandwidth(data));
  }
}
