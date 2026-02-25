/// A Dart-friendly API for encoding and decoding Opus audio packets.
///
/// Call [initOpus] with a loaded `DynamicLibrary` before using any
/// encoder, decoder, or stream transformer.

export 'src/opus_dart_decoder.dart';
export 'src/opus_dart_encoder.dart';
export 'src/opus_dart_misc.dart' hide ApiObject, opus;
export 'src/opus_dart_packet.dart';
export 'src/opus_dart_streaming.dart';
