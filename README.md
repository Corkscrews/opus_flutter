# opus_codec

A Flutter package that sets up the [Opus audio codec](https://opus-codec.org/) for [opus_codec_dart](https://pub.dev/packages/opus_codec_dart) on every Flutter platform.

## Overview

`opus_codec_dart` vendors the libopus sources and builds them with a [Dart build hook](https://dart.dev/tools/hooks) as a native code asset, so native platforms need no per-platform plugin or prebuilt binary. The web uses a WASM build of the same sources, shipped by `opus_codec_web`.

### Packages

| Package | Directory | Version |
|---------|-----------|---------|
| [opus_codec](https://pub.dev/packages/opus_codec) | [opus_flutter](./opus_flutter) | 4.0.0 |
| [opus_codec_dart](https://pub.dev/packages/opus_codec_dart) | [opus_dart](./opus_dart) | 4.0.0 |
| [opus_codec_platform_interface](https://pub.dev/packages/opus_codec_platform_interface) | [opus_flutter_platform_interface](./opus_flutter_platform_interface) | 4.0.0 |
| [opus_codec_web](https://pub.dev/packages/opus_codec_web) | [opus_flutter_web](./opus_flutter_web) | 4.0.0 |

The 3.x platform packages (`opus_codec_android`, `_ios`, `_linux`, `_macos`, `_windows`) are retired; their published versions stay on pub.dev.

## Platform support

| Android | iOS | Linux | macOS | Web | Windows |
|:-------:|:---:|:-----:|:-----:|:---:|:-------:|
|    ✅    |  ✅  |   ✅   |   ✅   |  ✅  |    ✅    |

## Getting started

Add `opus_codec` to your `pubspec.yaml`:

```yaml
dependencies:
  opus_codec: ^4.0.0
  opus_codec_dart: ^4.0.0
```

Native platforms also need a C compiler at build time (Xcode, the Android NDK, gcc/clang or MSVC).

## Usage

```dart
import 'package:opus_codec/opus_codec.dart' as opus_codec;
import 'package:opus_codec_dart/opus_codec_dart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await opus_codec.initializeOpus();
  // opus_codec_dart functions are now available
}
```

`initializeOpus()` sets up libopus for the platform. On native platforms it uses the libopus code asset built by `opus_codec_dart`, which needs a C compiler at build time (Xcode, the Android NDK, gcc/clang or MSVC). On the web it loads the WASM backend. See the [example app](./opus_flutter/example) for a complete encoding/decoding demo.

## Why are opus_codec_dart and opus_codec separate packages?

Dart is more than just Flutter. With this split, Flutter developers get a convenient way to load opus, while `opus_codec_dart` can still be used without Flutter (e.g. on headless servers). Developers are also free to load opus themselves without using `opus_codec_dart`.

## Opus version

libopus **1.6.1** is vendored in [opus_dart/native](./opus_dart/native) and pinned in [`libopus.json`](./opus_dart/native/libopus.json), with Xiph's published SHA-256.

## How opus is included per platform

| Platform | Method |
|----------|--------|
| Android, iOS, Linux, macOS, Windows | Compiled from the vendored sources by `opus_codec_dart`'s build hook and bundled as a code asset |
| Web      | Compiled to WebAssembly from the same sources with Emscripten (`./build_wasm.sh`) |

### Updating libopus

The [Update libopus](./.github/workflows/update-libopus.yml) workflow checks Xiph's releases weekly and opens a PR with the new pin, re-vendored sources, regenerated bindings and rebuilt WASM. To do it locally:

```bash
python3 scripts/vendor_libopus.py --update 1.6.1   # pin, verify, vendor
cd opus_dart && dart run tool/ffigen.dart           # regenerate bindings
./build_wasm.sh                                     # rebuild the web backend (Docker)
```

## Scripts

The `scripts/` directory contains helper scripts for local development.

| Script | Description |
|--------|-------------|
| [`scripts/unit_tests.sh`](./scripts/unit_tests.sh) | Runs all unit tests across every package and collects per-package lcov coverage reports. When `lcov` is available, all reports are merged into a single `coverage/lcov.info` at the repository root and an HTML report is generated at `coverage/html/index.html`. |
| [`scripts/analyze.sh`](./scripts/analyze.sh) | Runs static analysis (`flutter analyze` / `dart analyze`) across every package and prints a pass/fail summary. Exits with a non-zero code if any package has analysis errors. |
| [`scripts/format.sh`](./scripts/format.sh) | Checks that all Dart code is formatted correctly (`dart format --set-exit-if-changed`). Exits with a non-zero code if any file needs formatting. |
| [`scripts/check_dependencies.sh`](./scripts/check_dependencies.sh) | Reports outdated dependencies and checks pub.dev for discontinued or abandoned packages. Requires `curl` and `python3` for the discontinued-package checks. |
| [`scripts/publish.sh`](./scripts/publish.sh) | Publishes all packages to pub.dev in dependency order (core, web, then the Flutter package). Runs in dry-run mode by default; pass `--publish` to push to pub.dev. |

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

- Dart SDK `>=3.10.0`
- Flutter `>=3.38.1`
- A C compiler for native builds

## License

BSD-2-Clause. See [LICENSE](./LICENSE) for details.
