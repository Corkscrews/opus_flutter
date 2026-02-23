import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:opus_codec_platform_interface/opus_codec_platform_interface.dart';
import 'package:path_provider/path_provider.dart';

/// An implementation of [OpusFlutterPlatform] for Linux.
///
/// Loads a bundled libopus shared library from Flutter assets. If the bundled
/// binary cannot be loaded (e.g. missing asset or unsupported architecture),
/// falls back to the system-installed `libopus.so.0`.
class OpusFlutterLinux extends OpusFlutterPlatform {
  /// Registers this class as the default instance of [OpusFlutterPlatform].
  static void registerWith() {
    OpusFlutterPlatform.instance = OpusFlutterLinux();
  }

  /// Opens the opus shared library.
  ///
  /// First attempts to load a bundled binary from Flutter assets (copied to a
  /// temporary directory). If that fails for any reason (missing asset,
  /// unsupported architecture, etc.), falls back to the system-installed
  /// `libopus.so.0`.
  ///
  /// Throws an [ArgumentError] if neither the bundled nor the system library
  /// can be loaded.
  // coverage:ignore-start
  @override
  Future<Object> load() async {
    try {
      final path = await _copyBundledLibrary();
      return DynamicLibrary.open(path);
    } catch (_) {
      try {
        return DynamicLibrary.open('libopus.so.0');
      } catch (_) {
        throw ArgumentError('Failed to load libopus. '
            'Neither the bundled library nor the system-installed '
            'libopus.so.0 could be opened. '
            'Install libopus with: sudo apt install libopus0');
      }
    }
  }
  // coverage:ignore-end

  // coverage:ignore-start
  static Future<String> _copyBundledLibrary() async {
    final tmpPath = (await getTemporaryDirectory()).absolute.path;
    final dir = Directory('$tmpPath/opus_flutter_linux/opus').absolute;
    await dir.create(recursive: true);

    final String src;
    final String dst;
    if (Abi.current() == Abi.linuxX64) {
      src = 'libopus_x86_64.so.blob';
      dst = 'libopus_x86_64.so';
    } else if (Abi.current() == Abi.linuxArm64) {
      src = 'libopus_aarch64.so.blob';
      dst = 'libopus_aarch64.so';
    } else {
      throw UnsupportedError(
          'Unsupported Linux architecture: ${Abi.current()}');
    }

    final f = File('${dir.path}/$dst');
    if (!(await f.exists())) {
      final data =
          await rootBundle.load('packages/opus_codec_linux/assets/$src');
      await f.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    return f.path;
  }
  // coverage:ignore-end
}
