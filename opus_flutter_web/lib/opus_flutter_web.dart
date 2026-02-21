import 'dart:async';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';
import 'package:wasm_ffi/ffi.dart';

/// An implementation of [OpusFlutterPlatform] for web.
class OpusFlutterWeb extends OpusFlutterPlatform {
  static void registerWith(Registrar registrar) {
    OpusFlutterPlatform.instance = OpusFlutterWeb();
  }

  DynamicLibrary? _library;

  /// Opens the WebAssembly opus library contained in this plugin.
  ///
  /// Uses [DynamicLibrary.open] which handles JS injection, Emscripten module
  /// compilation, and memory setup. Registers the created memory as global if
  /// none is set yet.
  @override
  Future<Object> load() async {
    _library ??= await DynamicLibrary.open(
      './assets/packages/opus_flutter_web/assets/libopus.js',
      moduleName: 'libopus',
      useAsGlobal: GlobalMemory.ifNotSet,
    );
    return _library!;
  }
}
