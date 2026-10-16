import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:opus_codec_dart/opus_codec_dart.dart';
import 'package:opus_codec_platform_interface/opus_codec_platform_interface.dart';

/// Initializes libopus for the current platform. Call it once, before using
/// any encoder, decoder or stream.
///
/// On native platforms the libopus code asset built by `opus_codec_dart` is
/// used, so nothing is loaded from the platform plugins. On the web the WASM
/// backend is loaded through the web plugin and handed to `initOpus`.
Future<void> initializeOpus() async {
  if (kIsWeb) {
    initOpus(await OpusFlutterPlatform.instance.load());
  } else {
    initOpus();
  }
}
