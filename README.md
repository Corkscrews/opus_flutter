# opus_codec

A Flutter plugin that provides the [Opus audio codec](https://opus-codec.org/) as a `DynamicLibrary` for use with [opus_codec_dart](https://pub.dev/packages/opus_codec_dart) on Flutter platforms.

## Overview

This monorepo contains a federated Flutter plugin that loads libopus on each supported platform. The plugin follows the [federated plugin architecture](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins), splitting platform implementations into separate packages.

### Packages

| Package | Directory | Version |
|---------|-----------|---------|
| [opus_codec](https://pub.dev/packages/opus_codec) | [opus_flutter](./opus_flutter) | 3.0.4 |
| [opus_codec_dart](https://pub.dev/packages/opus_codec_dart) | [opus_dart](./opus_dart) | 3.0.4 |
| [opus_codec_platform_interface](https://pub.dev/packages/opus_codec_platform_interface) | [opus_flutter_platform_interface](./opus_flutter_platform_interface) | 3.0.4 |
| [opus_codec_android](https://pub.dev/packages/opus_codec_android) | [opus_flutter_android](./opus_flutter_android) | 3.0.4 |
| [opus_codec_ios](https://pub.dev/packages/opus_codec_ios) | [opus_flutter_ios](./opus_flutter_ios) | 3.0.4 |
| [opus_codec_linux](https://pub.dev/packages/opus_codec_linux) | [opus_flutter_linux](./opus_flutter_linux) | 3.0.4 |
| [opus_codec_macos](https://pub.dev/packages/opus_codec_macos) | [opus_flutter_macos](./opus_flutter_macos) | 3.0.4 |
| [opus_codec_web](https://pub.dev/packages/opus_codec_web) | [opus_flutter_web](./opus_flutter_web) | 3.0.4 |
| [opus_codec_windows](https://pub.dev/packages/opus_codec_windows) | [opus_flutter_windows](./opus_flutter_windows) | 3.0.4 |

## Platform support

| Android | iOS | Linux | macOS | Web | Windows |
|:-------:|:---:|:-----:|:-----:|:---:|:-------:|
|    ✅    |  ✅  |   ✅   |   ✅   |  ✅  |    ✅    |

## Getting started

Add `opus_codec` to your `pubspec.yaml`:

```yaml
dependencies:
  opus_codec: ^3.0.4
  opus_codec_dart: ^3.0.4
```

Platform packages are automatically included through the federated plugin system -- you don't need to add them individually.

## Usage

```dart
import 'package:opus_codec/opus_codec.dart' as opus_codec;
import 'package:opus_codec_dart/opus_codec_dart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initOpus(await opus_codec.load());
  // opus_codec_dart functions are now available
}
```

The `load()` function returns a `DynamicLibrary` on native platforms (via `dart:ffi`) or a `wasm_ffi` `DynamicLibrary` on the web. See the [example app](./opus_flutter/example) for a complete encoding/decoding demo.

## Why are opus_codec_dart and opus_codec separate packages?

Dart is more than just Flutter. With this split, Flutter developers get a convenient way to load opus, while `opus_codec_dart` can still be used without Flutter (e.g. on headless servers). Developers are also free to load opus themselves without using `opus_codec_dart`.

## Opus version

Currently, opus **1.5.2** is bundled (on Linux, the system-installed version is used).

## How opus is included per platform

| Platform | Method |
|----------|--------|
| Android  | Built from source via CMake ([details](./opus_flutter_android/README.md)) |
| iOS      | Prebuilt XCFramework, supports CocoaPods and Swift Package Manager ([details](./opus_flutter_ios/README.md)) |
| Linux    | System library `libopus.so.0` ([details](./opus_flutter_linux/README.md)) |
| macOS    | Prebuilt XCFramework, supports CocoaPods and Swift Package Manager ([details](./opus_flutter_macos/README.md)) |
| Web      | Compiled to WebAssembly with Emscripten ([details](./opus_flutter_web/README.md)) |
| Windows  | Prebuilt DLLs for x86/x64 ([details](./opus_flutter_windows/README.md)) |

## Scripts

The `scripts/` directory contains helper scripts for local development.

| Script | Description |
|--------|-------------|
| [`scripts/unit_tests.sh`](./scripts/unit_tests.sh) | Runs all unit tests across every package and collects per-package lcov coverage reports. When `lcov` is available, all reports are merged into a single `coverage/lcov.info` at the repository root and an HTML report is generated at `coverage/html/index.html`. |
| [`scripts/analyze.sh`](./scripts/analyze.sh) | Runs static analysis (`flutter analyze` / `dart analyze`) across every package and prints a pass/fail summary. Exits with a non-zero code if any package has analysis errors. |
| [`scripts/format.sh`](./scripts/format.sh) | Checks that all Dart code is formatted correctly (`dart format --set-exit-if-changed`). Exits with a non-zero code if any file needs formatting. |
| [`scripts/check_dependencies.sh`](./scripts/check_dependencies.sh) | Reports outdated dependencies and checks pub.dev for discontinued or abandoned packages. Requires `curl` and `python3` for the discontinued-package checks. |

### Running unit tests

```bash
./scripts/unit_tests.sh
```

The script automatically runs `dart run build_runner build --delete-conflicting-outputs` for `opus_codec_dart` before executing its tests, so Mockito mock classes are always up to date.

**Requirements:**

- `flutter` (stable channel) with `dart` bundled
- `lcov` (optional, for merged HTML coverage report) — `brew install lcov`
- `dart pub global activate coverage` (for `opus_codec_dart` pure-Dart coverage)

### Running static analysis

```bash
./scripts/analyze.sh
```

**Requirements:**

- `flutter` (stable channel) with `dart` bundled

## Requirements

- Dart SDK `>=3.4.0`
- Flutter `>=3.22.0`

## License

BSD-2-Clause. See [LICENSE](./LICENSE) for details.
