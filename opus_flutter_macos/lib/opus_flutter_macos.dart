import 'dart:async';
import 'dart:ffi';

import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

/// An implementation of [OpusFlutterPlatform] for macOS.
class OpusFlutterMacOS extends OpusFlutterPlatform {
  /// Opens the opus library linked into this plugin.
  @override
  Future<Object> load() async {
    return DynamicLibrary.process();
  }
}
