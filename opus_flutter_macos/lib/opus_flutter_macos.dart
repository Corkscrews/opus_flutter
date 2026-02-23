import 'dart:async';
import 'dart:ffi';

import 'package:opus_codec_platform_interface/opus_codec_platform_interface.dart';

/// An implementation of [OpusFlutterPlatform] for macOS.
class OpusFlutterMacOS extends OpusFlutterPlatform {
  /// Registers this class as the default instance of [OpusFlutterPlatform].
  static void registerWith() {
    OpusFlutterPlatform.instance = OpusFlutterMacOS();
  }

  /// Opens the opus library linked into this plugin.
  // coverage:ignore-start
  @override
  Future<Object> load() async {
    return DynamicLibrary.process();
  }
  // coverage:ignore-end
}
