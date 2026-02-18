import 'dart:ffi';

import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

/// An implementation of [OpusFlutterPlatform] for Linux.
///
/// On Linux, opus is loaded as a system library. Make sure `libopus` is
/// installed on the system (e.g. `sudo apt install libopus0` on Debian/Ubuntu
/// or `sudo dnf install opus` on Fedora).
class OpusFlutterLinux extends OpusFlutterPlatform {
  /// Registers this class as the default instance of [OpusFlutterPlatform].
  static void registerWith() {
    OpusFlutterPlatform.instance = OpusFlutterLinux();
  }

  /// Opens the system-installed opus shared library.
  @override
  Future<Object> load() async {
    return DynamicLibrary.open('libopus.so.0');
  }
}
