import 'dart:async';
import 'dart:ffi';

import 'package:opus_codec_platform_interface/opus_codec_platform_interface.dart';

/// An implementation of [OpusFlutterPlatform] for Android.
class OpusFlutterAndroid extends OpusFlutterPlatform {
  /// Registers this class as the default instance of [OpusFlutterPlatform].
  static void registerWith() {
    OpusFlutterPlatform.instance = OpusFlutterAndroid();
  }

  /// Opens the shared opus library built by this plugin.
  // coverage:ignore-start
  @override
  Future<Object> load() async {
    return DynamicLibrary.open('libopus.so');
  }
  // coverage:ignore-end
}
