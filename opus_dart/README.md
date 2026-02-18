# opus_dart

Wraps [libopus](https://opus-codec.org/) in Dart, providing both raw FFI bindings and a Dart-friendly API for encoding and decoding.

Vendored from [EPNW/opus_dart](https://github.com/EPNW/opus_dart) (v3.0.1) and updated for Dart 3 and `wasm_ffi` 2.x compatibility. This package is not published to pub.dev — it lives in the repository at `opus_dart/` and is consumed via path dependency.

**Bundled opus version: 1.5.2**

## Table of Contents

- [Choosing the Right API](#choosing-the-right-api)
  - [Raw FFI Bindings](#raw-ffi-bindings)
  - [Dart-Friendly API](#dart-friendly-api)
- [Initialization](#initialization)
  - [With Flutter (recommended)](#with-flutter-recommended)
  - [Bindings Only](#bindings-only)
- [Cross-Platform FFI](#cross-platform-ffi)
- [Encoder CTL](#encoder-ctl)

## Choosing the Right API

### Raw FFI Bindings

The `lib/wrappers/` directory contains FFI bindings for most functions in the Opus headers. Each file corresponds to a group from the Opus API (`opus_encoder`, `opus_decoder`, `opus_libinfo`, etc.). Documentation on the bound functions was copied from the Opus headers.

### Dart-Friendly API

Most users should use the higher-level Dart API, which handles memory allocation automatically:

- **`SimpleOpusEncoder` / `SimpleOpusDecoder`** — Allocate and free native memory on every call. Easy to use; best starting point.
- **`BufferedOpusEncoder` / `BufferedOpusDecoder`** — Allocate native memory once. You write directly to the buffer and update the input index. May improve performance for high-throughput use cases.
- **`StreamOpusEncoder` / `StreamOpusDecoder`** — `StreamTransformer` implementations for encoding PCM streams to Opus packets or decoding Opus packets to PCM streams.

All encoder/decoder instances **must** be destroyed by calling `destroy()` to release native memory.

## Initialization

### With Flutter (recommended)

Use `opus_flutter` to load the native library, then pass it to `initOpus()`:

```dart
import 'package:opus_dart/opus_dart.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initOpus(await opus_flutter.load());
  print(getOpusVersion());
  runApp(const MyApp());
}
```

`opus_flutter` handles loading the correct binary for each platform (Android, iOS, macOS, Linux, Windows, Web).

### Bindings Only

If using the raw bindings without the Dart-friendly API, import the wrapper files with a prefix and create `FunctionsAndGlobals` instances directly:

```dart
import 'package:opus_dart/wrappers/opus_libinfo.dart' as opus_libinfo;
import 'package:opus_dart/wrappers/opus_encoder.dart' as opus_encoder;

late final opus_libinfo.FunctionsAndGlobals libinfo;
late final opus_encoder.FunctionsAndGlobals encoder;

void init(DynamicLibrary lib) {
  libinfo = opus_libinfo.FunctionsAndGlobals(lib);
  encoder = opus_encoder.FunctionsAndGlobals(lib);
}
```

## Cross-Platform FFI

`opus_dart` works on both native platforms (`dart:ffi`) and web (`wasm_ffi`). This is handled by `proxy_ffi.dart`, which uses Dart conditional exports:

```dart
export 'dart:ffi' if (dart.library.js_interop) 'package:wasm_ffi/ffi.dart';
```

All source files import `proxy_ffi.dart` instead of `dart:ffi` directly, so the correct types are resolved at compile time. On native, `initOpus()` receives a `dart:ffi` `DynamicLibrary`; on web, a `wasm_ffi` `DynamicLibrary`. The parameter is typed as `Object` to avoid requiring callers to cast.

## Encoder CTL

To perform a CTL function on an Opus encoder, use `encoderCtl()` with a request constant and value. Import `opus_defines.dart` for the request constants:

```dart
import 'package:opus_dart/opus_dart.dart';
import 'package:opus_dart/wrappers/opus_defines.dart';

SimpleOpusEncoder createCbrEncoder() {
  final encoder = SimpleOpusEncoder(
    sampleRate: 8000,
    channels: 1,
    application: Application.restrictedLowdely,
  );
  encoder.encoderCtl(request: OPUS_SET_VBR_REQUEST, value: 0);
  encoder.encoderCtl(request: OPUS_SET_BITRATE_REQUEST, value: 15200);
  return encoder;
}
```

Note: although the C API's `opus_encoder_ctl` accepts variadic arguments, the Dart binding only supports one argument. This is sufficient for most use cases.
