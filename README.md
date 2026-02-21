# opus_flutter

A Flutter plugin that provides the [Opus audio codec](https://opus-codec.org/) as a `DynamicLibrary` for use with [opus_dart](https://pub.dev/packages/opus_dart) on Flutter platforms.

## Overview

This monorepo contains a federated Flutter plugin that loads libopus on each supported platform. The plugin follows the [federated plugin architecture](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins), splitting platform implementations into separate packages.

### Packages

| Package | Description | Version |
|---------|-------------|---------|
| [opus_flutter](./opus_flutter) | Main app-facing package | 3.0.3 |
| [opus_flutter_platform_interface](./opus_flutter_platform_interface) | Common platform interface | 3.0.0 |
| [opus_flutter_android](./opus_flutter_android) | Android implementation | 3.0.1 |
| [opus_flutter_ios](./opus_flutter_ios) | iOS implementation | 3.0.1 |
| [opus_flutter_linux](./opus_flutter_linux) | Linux implementation | 3.0.0 |
| [opus_flutter_macos](./opus_flutter_macos) | macOS implementation | 3.0.0 |
| [opus_flutter_web](./opus_flutter_web) | Web implementation | 3.0.3 |
| [opus_flutter_windows](./opus_flutter_windows) | Windows implementation | 3.0.0 |

## Platform support

| Android | iOS | Linux | macOS | Web | Windows |
|:-------:|:---:|:-----:|:-----:|:---:|:-------:|
|    ✅    |  ✅  |   ✅   |   ✅   |  ✅  |    ✅    |

## Getting started

Add `opus_flutter` to your `pubspec.yaml`:

```yaml
dependencies:
  opus_flutter: ^3.0.0
  opus_dart: ^3.0.1
```

Platform packages are automatically included through the federated plugin system -- you don't need to add them individually.

## Usage

```dart
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initOpus(await opus_flutter.load());
  // opus_dart functions are now available
}
```

The `load()` function returns a `DynamicLibrary` on native platforms (via `dart:ffi`) or a `wasm_ffi` `DynamicLibrary` on the web. See the [example app](./opus_flutter/example) for a complete encoding/decoding demo.

## Why are opus_dart and opus_flutter separate packages?

Dart is more than just Flutter. With this split, Flutter developers get a convenient way to load opus, while `opus_dart` can still be used without Flutter (e.g. on headless servers). Developers are also free to load opus themselves without using `opus_dart`.

## Opus version

Currently, opus **1.5.2** is bundled (on Linux, the system-installed version is used).

## How opus is included per platform

| Platform | Method |
|----------|--------|
| Android  | Built from source via CMake ([details](./opus_flutter_android/README.md)) |
| iOS      | Prebuilt XCFramework ([details](./opus_flutter_ios/README.md)) |
| Linux    | System library `libopus.so.0` ([details](./opus_flutter_linux/README.md)) |
| macOS    | Prebuilt XCFramework ([details](./opus_flutter_macos/README.md)) |
| Web      | Compiled to WebAssembly with Emscripten ([details](./opus_flutter_web/README.md)) |
| Windows  | Prebuilt DLLs for x86/x64 ([details](./opus_flutter_windows/README.md)) |

## Scripts

The `scripts/` directory contains helper scripts for local development.

| Script | Description |
|--------|-------------|
| [`scripts/unit_tests.sh`](./scripts/unit_tests.sh) | Runs all unit tests across every package and collects per-package lcov coverage reports. When `lcov` is available, all reports are merged into a single `coverage/lcov.info` at the repository root and an HTML report is generated at `coverage/html/index.html`. |
| [`scripts/analyze.sh`](./scripts/analyze.sh) | Runs static analysis (`flutter analyze` / `dart analyze`) across every package and prints a pass/fail summary. Exits with a non-zero code if any package has analysis errors. |

### Running unit tests

```bash
./scripts/unit_tests.sh
```

The script automatically runs `dart run build_runner build --delete-conflicting-outputs` for `opus_dart` before executing its tests, so Mockito mock classes are always up to date.

**Requirements:**

- `flutter` (stable channel) with `dart` bundled
- `lcov` (optional, for merged HTML coverage report) — `brew install lcov`
- `dart pub global activate coverage` (for `opus_dart` pure-Dart coverage)

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

BSD-2-Clause. See [LICENSE](./opus_flutter/LICENSE) for details.
