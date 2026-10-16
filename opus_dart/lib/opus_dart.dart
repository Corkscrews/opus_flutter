/// A Dart-friendly API for encoding and decoding Opus audio packets.
///
/// Call [initOpus] before using any encoder, decoder, or stream transformer.
/// On native platforms it takes no arguments; libopus is a bundled code asset.

export 'src/opus_dart_decoder.dart';
export 'src/opus_dart_encoder.dart';
export 'src/opus_dart_misc.dart' hide ApiObject, opus;
export 'src/opus_dart_packet.dart';
export 'src/opus_dart_streaming.dart';
