# opus_codec

Sets up the [Opus audio codec](https://opus-codec.org/) for [opus_codec_dart](https://pub.dev/packages/opus_codec_dart) on every Flutter platform.

## Usage

Add `opus_codec` and `opus_codec_dart` to your `pubspec.yaml`:

```yaml
dependencies:
  opus_codec: ^4.0.0
  opus_codec_dart: ^4.0.0
```

No per-platform packages are needed. Native builds compile libopus with the platform's C compiler.

```dart
import 'package:opus_codec/opus_codec.dart' as opus_codec;
import 'package:opus_codec_dart/opus_codec_dart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await opus_codec.initializeOpus();
  // opus_codec_dart functions are now available
}
```

`initializeOpus()` sets up libopus for the platform. On native platforms it uses the libopus code asset built by `opus_codec_dart`, which needs a C compiler at build time. On the web it loads the WASM backend. See the [example app](./example) for a complete record-and-playback demo.

## Platform support

| Android | iOS | Linux | macOS | Web | Windows |
|:-------:|:---:|:-----:|:-----:|:---:|:-------:|
|    ✅    |  ✅  |   ✅   |   ✅   |  ✅  |    ✅    |

## How opus is included per platform

| Platform | Method |
|----------|--------|
| Android, iOS, Linux, macOS, Windows | Compiled from the sources vendored in `opus_codec_dart` by its build hook, bundled as a code asset |
| Web      | WebAssembly build of the same sources, shipped by `opus_codec_web` |

## Why are opus_codec_dart and opus_codec separate packages?

Dart is more than just Flutter. With this split, Flutter developers get a convenient way to load opus, while `opus_codec_dart` can still be used without Flutter (e.g. on headless servers). Developers are also free to load opus themselves without using `opus_codec_dart`.

## Opus version

libopus **1.6.1**.

## License

BSD-2-Clause. See [LICENSE](./LICENSE) for details.
