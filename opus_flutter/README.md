# opus_codec

A Flutter plugin that provides the [Opus audio codec](https://opus-codec.org/) as a `DynamicLibrary` for use with [opus_codec_dart](https://pub.dev/packages/opus_codec_dart).

## Usage

Add `opus_codec` and `opus_codec_dart` to your `pubspec.yaml`:

```yaml
dependencies:
  opus_codec: ^3.0.0
  opus_codec_dart: ^3.0.0
```

Platform packages are automatically included through the federated plugin system.

```dart
import 'package:opus_codec/opus_codec.dart' as opus_codec;
import 'package:opus_codec_dart/opus_codec_dart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initOpus(await opus_codec.load());
  // opus_codec_dart functions are now available
}
```

The `load()` function returns a `DynamicLibrary` on native platforms (via `dart:ffi`) or a `wasm_ffi` `DynamicLibrary` on the web. See the [example app](./example) for a complete record-and-playback demo.

## Platform support

| Android | iOS | Linux | macOS | Web | Windows |
|:-------:|:---:|:-----:|:-----:|:---:|:-------:|
|    ✅    |  ✅  |   ✅   |   ✅   |  ✅  |    ✅    |

## How opus is included per platform

| Platform | Method |
|----------|--------|
| Android  | Built from source via CMake |
| iOS      | Prebuilt XCFramework |
| Linux    | Bundled shared library with system fallback |
| macOS    | Prebuilt XCFramework |
| Web      | Compiled to WebAssembly with Emscripten |
| Windows  | Prebuilt DLLs for x86/x64 |

## Why are opus_codec_dart and opus_codec separate packages?

Dart is more than just Flutter. With this split, Flutter developers get a convenient way to load opus, while `opus_codec_dart` can still be used without Flutter (e.g. on headless servers). Developers are also free to load opus themselves without using `opus_codec_dart`.

## Opus version

Currently, opus **1.5.2** is bundled.

## License

BSD-2-Clause. See [LICENSE](./LICENSE) for details.
