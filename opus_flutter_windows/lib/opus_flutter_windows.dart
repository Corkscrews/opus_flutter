import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';
import 'package:path_provider/path_provider.dart';

/// An implementation of [OpusFlutterPlatform] for Windows.
///
/// Loads a prebuilt libopus DLL from Flutter assets. The DLL is copied to the
/// system temporary directory on first use and reused on subsequent calls.
class OpusFlutterWindows extends OpusFlutterPlatform {
  static const String _licenseFile = 'opus_license.txt';

  // coverage:ignore-start
  static Future<String> _copyFiles() async {
    final tmpPath = (await getTemporaryDirectory()).absolute.path;
    final dir = Directory('$tmpPath/opus_flutter_windows/opus').absolute;
    await dir.create(recursive: true);

    ByteData data;
    File f = File('${dir.path}/$_licenseFile');
    if (!(await f.exists())) {
      data = await rootBundle
          .load('packages/opus_flutter_windows/assets/$_licenseFile');
      await f.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }

    final String src;
    final String dst;
    if (Abi.current() == Abi.windowsX64) {
      src = 'libopus_x64.dll.blob';
      dst = 'libopus_x64.dll';
    } else if (Abi.current() == Abi.windowsIA32) {
      src = 'libopus_x86.dll.blob';
      dst = 'libopus_x86.dll';
    } else {
      throw UnsupportedError(
          'Unsupported Windows architecture: ${Abi.current()}');
    }

    f = File('${dir.path}/$dst');
    if (!(await f.exists())) {
      data = await rootBundle.load('packages/opus_flutter_windows/assets/$src');
      await f.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    return f.path;
  }
  // coverage:ignore-end

  /// Registers the Windows implementation.
  static void registerWith() {
    OpusFlutterPlatform.instance = OpusFlutterWindows();
  }

  /// Opens the opus DLL bundled with this plugin.
  ///
  /// Throws an [ArgumentError] if the library cannot be loaded.
  // coverage:ignore-start
  @override
  Future<Object> load() async {
    try {
      final libPath = await _copyFiles();
      return DynamicLibrary.open(libPath);
    } catch (e) {
      throw ArgumentError('Failed to load libopus on Windows: $e');
    }
  }
  // coverage:ignore-end
}
