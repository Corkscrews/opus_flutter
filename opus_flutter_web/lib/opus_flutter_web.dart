import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';
import 'package:inject_js/inject_js.dart' as InjectJs;
import 'package:wasm_ffi/wasm_ffi.dart';
import 'package:wasm_ffi/wasm_ffi_modules.dart';

/// An implementation of [OpusFlutterPlatform] for web.
class OpusFlutterWeb extends OpusFlutterPlatform {
  static void registerWith(Registrar registrar) {
    OpusFlutterPlatform.instance = OpusFlutterWeb();
  }

  bool _injected = false;
  Module? _module;

  /// Opens the WebAssembly opus library contained in this plugin and
  /// injects the JavaScript glue if necessary.
  ///
  /// Registers the memory of the created [wasm_ffi DynamicLibrary](https://pub.dev/documentation/wasm_ffi/latest/wasm_ffi/DynamicLibrary-class.html)
  /// as [Memory.global] if there is no global memory yet.
  @override
  Future<Object> load() async {
    if (!_injected) {
      await InjectJs.importLibrary(
          './assets/packages/opus_flutter_web/assets/libopus.js');
      _injected = true;
    }
    if (_module == null) {
      Memory.init();
      ByteData wasmBinary = await rootBundle
          .load('packages/opus_flutter_web/assets/libopus.wasm');
      _module = await EmscriptenModule.compile(
          {
            'wasmBinary': wasmBinary.buffer.asUint8List(
                wasmBinary.offsetInBytes, wasmBinary.lengthInBytes),
          },
          'libopus');
    }
    return DynamicLibrary.fromModule(_module!);
  }
}
