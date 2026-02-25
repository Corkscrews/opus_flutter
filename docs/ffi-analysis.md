# FFI and wasm_ffi Analysis

This document catalogues every use of `dart:ffi`, `package:ffi`, and `package:wasm_ffi`
across the project. Its purpose is to serve as a reference for identifying potential bugs,
memory safety issues, and behavioral differences between native and web platforms.

---

## 1. Conditional FFI Abstraction Layer

The project uses a single entry point to abstract over native FFI and web WASM FFI:

**`opus_dart/lib/src/proxy_ffi.dart`**

```dart
export 'dart:ffi' if (dart.library.js_interop) 'package:wasm_ffi/ffi.dart';
export 'init_ffi.dart' if (dart.library.js_interop) 'init_web.dart';
```

All downstream code imports `proxy_ffi.dart` instead of `dart:ffi` directly. This means
every `Pointer`, `DynamicLibrary`, `Allocator`, `NativeType`, and `Opaque` reference
resolves to either `dart:ffi` or `wasm_ffi/ffi.dart` at compile time.

**Implication:** Any behavioral difference between `dart:ffi` and `wasm_ffi` (e.g.
pointer arithmetic, `nullptr` handling, allocator semantics) silently affects all code
below this layer.

---

## 2. Initialization: Native vs Web

### 2.1 Native (`init_ffi.dart`)

```dart
ApiObject createApiObject(Object lib) {
  final library = lib as DynamicLibrary;
  return ApiObject(library, ffipackage.malloc);
}
```

- Casts the incoming `Object` to `dart:ffi` `DynamicLibrary`.
- Uses `package:ffi`'s `malloc` as the allocator.
- No opaque type registration needed on native.

### 2.2 Web (`init_web.dart`)

```dart
ApiObject createApiObject(Object lib) {
  final library = lib as DynamicLibrary;
  registerOpaqueType<opus_encoder.OpusEncoder>();
  registerOpaqueType<opus_decoder.OpusDecoder>();
  registerOpaqueType<opus_custom.OpusCustomEncoder>();
  registerOpaqueType<opus_custom.OpusCustomDecoder>();
  registerOpaqueType<opus_multistream.OpusMSEncoder>();
  registerOpaqueType<opus_multistream.OpusMSDecoder>();
  registerOpaqueType<opus_projection.OpusProjectionEncoder>();
  registerOpaqueType<opus_projection.OpusProjectionDecoder>();
  registerOpaqueType<opus_repacketizer.OpusRepacketizer>();
  registerOpaqueType<opus_custom.OpusCustomMode>();
  return ApiObject(library, library.allocator);
}
```

- Casts to `wasm_ffi` `DynamicLibrary`.
- Must register every `Opaque` subclass so `wasm_ffi` can handle pointer lookups.
- Uses `library.allocator` (WASM linear memory allocator) instead of `malloc`.
- (**Fixed** — previously `OpusRepacketizer` was registered twice and `OpusCustomMode`
  was missing. Now all 10 opaque types are registered exactly once.)

### 2.3 Differences Summary

| Aspect                 | Native (`dart:ffi`)              | Web (`wasm_ffi`)                   |
|------------------------|----------------------------------|------------------------------------|
| Allocator              | `malloc` from `package:ffi`      | `library.allocator`                |
| Opaque type setup      | Not needed                       | `registerOpaqueType<T>()` required |
| `DynamicLibrary` source| OS-level `.so`/`.dylib`/`.dll`   | Emscripten JS+WASM module          |
| `nullptr` semantics    | Backed by address `0`            | `wasm_ffi` emulation               |
| `free(nullptr)`        | Safe (C standard)                | Depends on `wasm_ffi` allocator    |

---

## 3. Library Loading Per Platform

Each platform package only touches FFI to obtain a `DynamicLibrary`. No allocation or
pointer work happens in these packages.

| Platform | Method | Notes |
|----------|--------|-------|
| Android  | `DynamicLibrary.open('libopus.so')` | Built by CMake via FetchContent |
| iOS      | `DynamicLibrary.process()` | Statically linked via xcframework |
| macOS    | `DynamicLibrary.process()` | Statically linked via xcframework |
| Linux    | `DynamicLibrary.open(path)` then fallback to `DynamicLibrary.open('libopus.so.0')` | Bundled `.so` copied to temp dir |
| Windows  | `DynamicLibrary.open(libPath)` | Bundled DLL copied to temp dir |
| Web      | `DynamicLibrary.open('./assets/.../libopus.js', moduleName: 'libopus', useAsGlobal: GlobalMemory.ifNotSet)` | Emscripten module |

**Risk areas in platform loading:**

- **Linux/Windows:** The temp-directory copy strategy means the native library's
  lifetime is decoupled from the app. If the temp directory is cleaned while the app
  runs, subsequent `DynamicLibrary` uses will crash.
- **Linux fallback:** Falls back to system `libopus.so.0` which may be a different
  version than what the bindings expect.

---

## 4. Native Binding Wrappers

Located in `opus_dart/lib/wrappers/`. These files define typedefs and use
`DynamicLibrary.lookupFunction` to resolve C symbols.

### 4.1 Opaque Types

```dart
final class OpusEncoder extends ffi.Opaque {}
final class OpusDecoder extends ffi.Opaque {}
final class OpusRepacketizer extends ffi.Opaque {}
final class OpusMSEncoder extends ffi.Opaque {}
final class OpusMSDecoder extends ffi.Opaque {}
final class OpusProjectionEncoder extends ffi.Opaque {}
final class OpusProjectionDecoder extends ffi.Opaque {}
final class OpusCustomEncoder extends ffi.Opaque {}
final class OpusCustomDecoder extends ffi.Opaque {}
final class OpusCustomMode extends ffi.Opaque {}
```

These are used as type parameters for `Pointer<T>` to represent C opaque structs.

### 4.2 Encoder Bindings (`opus_encoder.dart`)

Functions resolved via `lookupFunction`:

| C function | Dart signature | Notes |
|------------|---------------|-------|
| `opus_encoder_get_size` | `int Function(int)` | |
| `opus_encoder_create` | `Pointer<OpusEncoder> Function(int, int, int, Pointer<Int32>)` | Returns encoder state; error via out-pointer |
| `opus_encoder_init` | `int Function(Pointer<OpusEncoder>, int, int, int)` | |
| `opus_encode` | `int Function(Pointer<OpusEncoder>, Pointer<Int16>, int, Pointer<Uint8>, int)` | Returns encoded byte count or error |
| `opus_encode_float` | `int Function(Pointer<OpusEncoder>, Pointer<Float>, int, Pointer<Uint8>, int)` | |
| `opus_encoder_destroy` | `void Function(Pointer<OpusEncoder>)` | |
| `opus_encoder_ctl` | `int Function(Pointer<OpusEncoder>, int, int)` | Variadic in C, bound with fixed 3 args |

**`opus_encoder_ctl` binding concern:** The C function `opus_encoder_ctl` is variadic.
The binding hardcodes it to accept exactly `(st, request, va)` — three arguments.
This works for CTL requests that take a single `int` argument, but CTL requests that
take a pointer argument (e.g. `OPUS_GET_*` requests that write to an out-pointer)
cannot be used through this binding. The `int va` parameter would need to be a pointer
address cast to `int`, which is fragile and non-portable. On web/WASM, pointer addresses
in the WASM linear memory space are 32-bit offsets, so passing them as `int` might work
by accident, but this pattern is error-prone.

### 4.3 Decoder Bindings (`opus_decoder.dart`)

Functions resolved via `lookupFunction`:

| C function | Dart signature |
|------------|---------------|
| `opus_decoder_get_size` | `int Function(int)` |
| `opus_decoder_create` | `Pointer<OpusDecoder> Function(int, int, Pointer<Int32>)` |
| `opus_decoder_init` | `int Function(Pointer<OpusDecoder>, int, int)` |
| `opus_decode` | `int Function(Pointer<OpusDecoder>, Pointer<Uint8>, int, Pointer<Int16>, int, int)` |
| `opus_decode_float` | `int Function(Pointer<OpusDecoder>, Pointer<Uint8>, int, Pointer<Float>, int, int)` |
| `opus_decoder_destroy` | `void Function(Pointer<OpusDecoder>)` |
| `opus_packet_parse` | `int Function(Pointer<Uint8>, int, Pointer<Uint8>, Pointer<Uint8>, int, Pointer<Int32>)` |
| `opus_packet_get_bandwidth` | `int Function(Pointer<Uint8>)` |
| `opus_packet_get_samples_per_frame` | `int Function(Pointer<Uint8>, int)` |
| `opus_packet_get_nb_channels` | `int Function(Pointer<Uint8>)` |
| `opus_packet_get_nb_frames` | `int Function(Pointer<Uint8>, int)` |
| `opus_packet_get_nb_samples` | `int Function(Pointer<Uint8>, int, int)` |
| `opus_decoder_get_nb_samples` | `int Function(Pointer<OpusDecoder>, Pointer<Uint8>, int)` |
| `opus_pcm_soft_clip` | `void Function(Pointer<Float>, int, int, Pointer<Float>)` |

### 4.4 Lib Info Bindings (`opus_libinfo.dart`)

| C function | Dart signature | Notes |
|------------|---------------|-------|
| `opus_get_version_string` | `Pointer<Uint8> Function()` | Returns pointer to static C string |
| `opus_strerror` | `Pointer<Uint8> Function(int)` | Returns pointer to static C string |

Both return `Pointer<Uint8>` rather than `Pointer<Utf8>`. The project manually walks
the bytes to find the null terminator (see Section 5.4).

---

## 5. Memory Management Patterns

### 5.1 The `ApiObject` and Global `opus` Variable

```dart
late ApiObject opus;

class ApiObject {
  final OpusLibInfoFunctions libinfo;
  final OpusEncoderFunctions encoder;
  final OpusDecoderFunctions decoder;
  final Allocator allocator;
  // ...
}
```

All allocation goes through `opus.allocator.call<T>(count)` and deallocation through
`opus.allocator.free(pointer)`. The global `opus` is set once via `initOpus()`.

**Risk:** `opus` is a `late` global. Any call before `initOpus()` throws
`LateInitializationError`. There is no guard or descriptive error message.

### 5.2 Allocation/Free Patterns

The project uses two distinct patterns:

#### Pattern A: Allocate-Use-Free (SimpleOpusEncoder, SimpleOpusDecoder, OpusPacketUtils)

```
allocate input buffer
allocate output buffer
call opus function
try {
  check error, copy result
} finally {
  free input buffer
  free output buffer
}
```

Every method call allocates and frees. This is safe but has higher overhead.

**Concern in SimpleOpusEncoder.encode/encodeFloat:** The `opus_encode` call happens
_before_ the `try` block. If `opus_encode` itself throws (not an opus error code, but
an actual Dart exception from FFI — e.g. segfault translated to an exception), then the
`finally` block still runs and frees the buffers. However, if the `allocator.call`
for `outputNative` throws after `inputNative` was already allocated, `inputNative` leaks.
The same pattern exists in the decoder.

Specifically in `SimpleOpusEncoder.encode`:

```dart
Pointer<Int16> inputNative = opus.allocator.call<Int16>(input.length);    // (1)
inputNative.asTypedList(input.length).setAll(0, input);
Pointer<Uint8> outputNative = opus.allocator.call<Uint8>(maxOutputSizeBytes); // (2)
// If (2) throws, (1) is leaked — no finally covers (1) at this point
int outputLength = opus.encoder.opus_encode(...);
try {
  // ...
} finally {
  opus.allocator.free(inputNative);   // only reached if opus_encode didn't throw
  opus.allocator.free(outputNative);
}
```

#### Pattern B: Preallocated Buffers (BufferedOpusEncoder, BufferedOpusDecoder)

Buffers are allocated once in the factory constructor and freed in `destroy()`.

```
factory constructor:
  allocate error, input, output, (softClipBuffer for decoder)
  create opus state
  if error: free input, output, (softClipBuffer), throw
  finally: free error

destroy():
  if not destroyed:
    mark destroyed
    destroy opus state
    free input, output, (softClipBuffer)
```

**Concern:** If `destroy()` is never called, all native memory leaks. There is no
Dart finalizer attached. `NativeFinalizer` (available since Dart 2.17) is not used
anywhere in the project.

**Concern in BufferedOpusEncoder factory:** If `opus_encoder_create` itself throws
(as opposed to returning an error code), the `input` and `output` buffers leak because
the `throw` path inside the `try` block only runs when `error.value != OPUS_OK`.

### 5.3 Pointer Lifetime in Streaming (`opus_dart_streaming.dart`)

`StreamOpusEncoder` and `StreamOpusDecoder` wrap `BufferedOpusEncoder`/`BufferedOpusDecoder`.
They expose `copyOutput` as a parameter:

- `copyOutput = true` (default): Output is copied to Dart heap via `Uint8List.fromList`.
- `copyOutput = false`: Output is a `Uint8List` view backed by native memory.

**Risk with `copyOutput = false`:** The view points into the preallocated native output
buffer. On the next encode/decode call, this buffer is overwritten. If a consumer holds
a reference to a previously yielded `Uint8List`, it will silently contain new data.
This is a use-after-write hazard.

The `StreamOpusDecoder` has an additional concern: when `forwardErrorCorrection` is
enabled and a packet is lost then recovered, the decoder calls `_decodeFec(true)` and
yields `_output()`, then immediately calls `_decodeFec(false)` and yields `_output()`
again. With `copyOutput = false`, the first yield's data is overwritten by the second
decode before the consumer processes it (in an `async*` generator, the consumer may
not have consumed the first yield yet).

### 5.4 String Handling (`_asString`)

(**Fixed** — `_asString` now has a `maxStringLength` (256) guard.)

```dart
String _asString(Pointer<Uint8> pointer) {
  int i = 0;
  while (i < maxStringLength && pointer[i] != 0) {
    i++;
  }
  if (i == maxStringLength) {
    throw StateError(
        '_asString: no null terminator found within $maxStringLength bytes');
  }
  return utf8.decode(pointer.asTypedList(i));
}
```

- Walks memory byte-by-byte until it finds a null terminator, up to `maxStringLength`.
- Throws `StateError` if no null terminator is found within the limit, preventing
  unbounded loops with invalid pointers.
- Only used with `opus_get_version_string()` and `opus_strerror()`, which return
  pointers to static C strings in libopus. These are well within the 256-byte limit.

### 5.5 `nullptr` Usage

`nullptr` is used in two contexts:

1. **Decoder packet loss:** When `input` is `null`, `inputNative` is set to `nullptr`
   and passed to `opus_decode`/`opus_decode_float`. This is correct per the opus API
   (null data pointer signals packet loss).

2. **Decoder free after packet loss:** After a null-input decode, the code
   `opus.allocator.free(inputNative)` is called where `inputNative == nullptr`. In C,
   `free(NULL)` is a no-op. The `dart:ffi` `malloc.free` from `package:ffi` also
   handles this safely. Whether `wasm_ffi`'s allocator handles `free(nullptr)` safely
   is implementation-dependent.

---

## 6. Error Handling Around FFI Calls

### 6.1 Error Code Checking

All opus API calls that return error codes are checked:

```dart
if (result < opus_defines.OPUS_OK) {
  throw OpusException(result);
}
```

`OpusException` calls `opus_strerror(errorCode)` to get a human-readable message.

### 6.2 Error Pointer Pattern

`opus_encoder_create` and `opus_decoder_create` write an error code to an out-pointer:

```dart
Pointer<Int32> error = opus.allocator.call<Int32>(1);
Pointer<OpusEncoder> encoder = opus.encoder.opus_encoder_create(..., error);
try {
  if (error.value != opus_defines.OPUS_OK) {
    throw OpusException(error.value);
  }
} finally {
  opus.allocator.free(error);
}
```

The error pointer is always freed in `finally`, which is correct.

### 6.3 Destroyed State

Encoder and decoder classes track `_destroyed` to prevent double-destroy:

```dart
void destroy() {
  if (!_destroyed) {
    _destroyed = true;
    opus.encoder.opus_encoder_destroy(_opusEncoder);
  }
}
```

All public methods (`encode`, `encodeFloat`, `decode`, `decodeFloat`, `encoderCtl`,
`pcmSoftClipOutputBuffer`) now check `_destroyed` at the top and throw
`OpusDestroyedError` before touching any native pointer. This matches the contract
documented in the abstract base classes. (**Fixed** — previously these methods had no
guard and would pass dangling pointers to opus after `destroy()`.)

---

## 7. Pointer Type Usage Inventory

| Pointer type | Where used | Purpose |
|-------------|-----------|---------|
| `Pointer<OpusEncoder>` | encoder implementations | Opaque encoder state |
| `Pointer<OpusDecoder>` | decoder implementations | Opaque decoder state |
| `Pointer<Int32>` | create functions | Error out-pointer (1 element) |
| `Pointer<Int16>` | encode/decode | s16le PCM sample buffer |
| `Pointer<Float>` | encode_float/decode_float | Float PCM sample buffer, soft clip state |
| `Pointer<Uint8>` | encode output, decode input, packet utils | Opus packet bytes, raw audio bytes |

### Pointer Casting

`BufferedOpusEncoder` and `BufferedOpusDecoder` allocate a single `Pointer<Uint8>` buffer
and cast it to `Pointer<Int16>` or `Pointer<Float>` depending on the encode/decode variant:

```dart
_inputBuffer.cast<Int16>()   // for encode()
_inputBuffer.cast<Float>()   // for encodeFloat()
_outputBuffer.cast<Int16>()  // for decode()
_outputBuffer.cast<Float>()  // for decodeFloat()
```

**Risk:** If the buffer byte count is not a multiple of the target type's size
(2 for Int16, 4 for Float), the `asTypedList` call after casting will include
partial elements or read past the intended boundary. The buffer size calculations
use `maxSamplesPerPacket` which accounts for channel count and sample rate, so this
should be safe in practice, but there is no runtime assertion.

---

## 8. `BufferedOpusDecoder` Output Buffer Sizing

(**Fixed** — both issues below have been corrected.)

The `BufferedOpusDecoder` factory previously defaulted `maxOutputBufferSizeBytes` to
`maxSamplesPerPacket(sampleRate, channels)` — a sample count, not a byte count. Since
the buffer must accommodate float output (4 bytes/sample), this was 4x too small for
`decodeFloat` with maximum-length opus frames (120ms). Fixed to
`4 * maxSamplesPerPacket(sampleRate, channels)`.

`StreamOpusDecoder` previously computed
`(floats ? 2 : 4) * maxSamplesPerPacket(...)` — inverted multipliers that allocated
less space for float (which needs more). Fixed to `(floats ? 4 : 2)`.

---

## 9. `opus_encoder_ctl` Variadic Binding

The C function `opus_encoder_ctl(OpusEncoder *st, int request, ...)` is variadic.
The Dart binding defines it with a fixed signature:

```dart
int opus_encoder_ctl(Pointer<OpusEncoder> st, int request, int va);
```

This works for setter-style CTLs like `OPUS_SET_BITRATE(value)` where the third
argument is an integer. However:

- **Getter-style CTLs** (e.g. `OPUS_GET_BITRATE`) expect a `Pointer<Int32>` as the
  third argument. Passing a pointer address as `int` is technically possible but
  non-portable and bypasses Dart's type safety.
- **On WASM:** Pointer values are offsets into WASM linear memory (32-bit). Passing
  them as Dart `int` (64-bit) and having the C side interpret them as `opus_int32*`
  requires that the upper 32 bits are zero, which should hold but is fragile.
- **No decoder_ctl:** There is no `opus_decoder_ctl` binding at all.

---

## 10. Potential Bugs and Risk Summary

| # | Risk | Location | Severity | Detail |
|---|------|----------|----------|--------|
| 1 | **Duplicate `registerOpaqueType` / missing `OpusCustomMode`** | `init_web.dart:28` | Fixed | Duplicate `OpusRepacketizer` removed; `OpusCustomMode` now registered. |
| 2 | **Memory leak if second allocation throws** | `SimpleOpusEncoder.encode`, `SimpleOpusDecoder.decode`, and float variants | Low | If the second `allocator.call` throws, the first allocation is not freed. |
| 3 | **No `NativeFinalizer`** | All encoder/decoder classes | Medium | If `destroy()` is never called, native memory leaks permanently. No GC-driven cleanup. |
| 4 | ~~**Use-after-destroy (dangling pointer)**~~ | `SimpleOpusEncoder`, `SimpleOpusDecoder`, `BufferedOpusEncoder`, `BufferedOpusDecoder` | ~~High~~ **Fixed** | All public methods now check `_destroyed` and throw `OpusDestroyedError` before touching native pointers. |
| 5 | **`copyOutput = false` use-after-write** | `StreamOpusEncoder`, `StreamOpusDecoder` | Medium | Yielded views point to native buffers that get overwritten on next call. |
| 6 | **`StreamOpusDecoder` FEC double-yield overwrites** | `opus_dart_streaming.dart:321-327` | Medium | With `copyOutput = false` and FEC, the first yielded output is overwritten before the consumer reads it. |
| 7 | ~~**Output buffer too small for float decode**~~ | `BufferedOpusDecoder` factory, `StreamOpusDecoder` constructor | ~~High~~ **Fixed** | `BufferedOpusDecoder` default now uses `4 * maxSamplesPerPacket`. `StreamOpusDecoder` multiplier corrected to `(floats ? 4 : 2)`. |
| 8 | **`free(nullptr)` on web** | `SimpleOpusDecoder.decode` finally block | Low | After null-input decode, `free(nullptr)` is called. Safe on native; behavior on `wasm_ffi` depends on allocator implementation. |
| 9 | ~~**`_asString` unbounded loop**~~ | `opus_dart_misc.dart` | ~~Low~~ **Fixed** | Now bounded by `maxStringLength` (256); throws `StateError` if no null terminator found. |
| 10 | **`opus_encoder_ctl` variadic binding** | `opus_encoder.dart` | Low | Hardcoded to 3 int args. Getter CTLs (pointer arg) cannot be used correctly. |
| 11 | **No `opus_decoder_ctl` binding** | `opus_decoder.dart` | Low | Decoder CTL operations are not exposed. |
| 12 | **`late` global `opus` without guard** | `opus_dart_misc.dart:55` | Low | Access before `initOpus()` gives unhelpful `LateInitializationError`. |
| 13 | **Linux/Windows temp dir library lifetime** | `opus_flutter_linux`, `opus_flutter_windows` | Low | If temp dir is cleaned while app runs, native calls will segfault. |

---

## 11. File-by-File FFI Reference

### Files that import FFI types

| File | Imports | Allocates | Frees | Calls native |
|------|---------|-----------|-------|-------------|
| `opus_dart/lib/src/proxy_ffi.dart` | conditional re-export | - | - | - |
| `opus_dart/lib/src/init_ffi.dart` | `dart:ffi`, `package:ffi` | - | - | - |
| `opus_dart/lib/src/init_web.dart` | `wasm_ffi/ffi.dart` | - | - | `registerOpaqueType` |
| `opus_dart/lib/src/opus_dart_misc.dart` | via `proxy_ffi` | - | - | `opus_get_version_string`, `opus_strerror` |
| `opus_dart/lib/src/opus_dart_encoder.dart` | via `proxy_ffi` | yes | yes | `opus_encoder_create/encode/encode_float/destroy/ctl` |
| `opus_dart/lib/src/opus_dart_decoder.dart` | via `proxy_ffi` | yes | yes | `opus_decoder_create/decode/decode_float/destroy/pcm_soft_clip` |
| `opus_dart/lib/src/opus_dart_packet.dart` | via `proxy_ffi` | yes | yes | `opus_packet_get_*` |
| `opus_dart/lib/src/opus_dart_streaming.dart` | (indirect via encoder/decoder) | - | - | (indirect) |
| `opus_dart/lib/wrappers/opus_encoder.dart` | via `proxy_ffi` as `ffi` | - | - | `lookupFunction` |
| `opus_dart/lib/wrappers/opus_decoder.dart` | via `proxy_ffi` as `ffi` | - | - | `lookupFunction` |
| `opus_dart/lib/wrappers/opus_libinfo.dart` | via `proxy_ffi` as `ffi` | - | - | `lookupFunction` |
| `opus_dart/lib/wrappers/opus_repacketizer.dart` | via `proxy_ffi` as `ffi` | - | - | opaque type only |
| `opus_dart/lib/wrappers/opus_projection.dart` | via `proxy_ffi` as `ffi` | - | - | opaque type only |
| `opus_dart/lib/wrappers/opus_multistream.dart` | via `proxy_ffi` as `ffi` | - | - | opaque type only |
| `opus_dart/lib/wrappers/opus_custom.dart` | via `proxy_ffi` as `ffi` | - | - | opaque type only |
| `opus_flutter_android/lib/...` | `dart:ffi` | - | - | `DynamicLibrary.open` |
| `opus_flutter_ios/lib/...` | `dart:ffi` | - | - | `DynamicLibrary.process` |
| `opus_flutter_macos/lib/...` | `dart:ffi` | - | - | `DynamicLibrary.process` |
| `opus_flutter_linux/lib/...` | `dart:ffi` | - | - | `DynamicLibrary.open` |
| `opus_flutter_windows/lib/...` | `dart:ffi` | - | - | `DynamicLibrary.open` |
| `opus_flutter_web/lib/...` | `wasm_ffi/ffi.dart` | - | - | `DynamicLibrary.open` (async) |

### Files that define opaque types

| File | Types |
|------|-------|
| `opus_encoder.dart` | `OpusEncoder` |
| `opus_decoder.dart` | `OpusDecoder` |
| `opus_repacketizer.dart` | `OpusRepacketizer` |
| `opus_multistream.dart` | `OpusMSEncoder`, `OpusMSDecoder` |
| `opus_projection.dart` | `OpusProjectionEncoder`, `OpusProjectionDecoder` |
| `opus_custom.dart` | `OpusCustomEncoder`, `OpusCustomDecoder`, `OpusCustomMode` |

---

## 12. Cross-Reference with wasm_ffi Documentation

This section audits the project against every rule and constraint documented in the
[wasm_ffi README](https://github.com/vm75/wasm_ffi/blob/main/README.md).

### 12.1 `DynamicLibrary.open` Is Async

**wasm_ffi rule:** `DynamicLibrary.open` is asynchronous on web, unlike `dart:ffi`.

**Project compliance:** Compliant. `OpusFlutterWeb.load()` uses `await DynamicLibrary.open(...)`:

```dart
_library ??= await DynamicLibrary.open(
  './assets/packages/opus_codec_web/assets/libopus.js',
  moduleName: 'libopus',
  useAsGlobal: GlobalMemory.ifNotSet,
);
```

### 12.2 Multiple Libraries and Memory Isolation

**wasm_ffi rule:** "If more than one library is loaded, the memory will continue to
refer to the first library. This breaks calls to later loaded libraries!" Each library
has its own memory, so objects cannot be shared between libraries.

**Project compliance:** Compliant. Only one WASM library (`libopus`) is loaded. The
`useAsGlobal: GlobalMemory.ifNotSet` parameter sets the library's memory as the global
`Memory` instance (only if no global is set yet), which is correct for a single-library
application.

**Risk if extended:** If a future dependency also loads a WASM library and sets global
memory, `GlobalMemory.ifNotSet` would leave the first library's memory as global. Any
`Pointer.fromAddress()` calls (including `nullptr`) would still reference that first
library's memory. Since the project explicitly passes `library.allocator` through
`ApiObject`, allocation/free operations are correctly bound to the opus library's
memory regardless.

### 12.3 Opaque Type Registration

**wasm_ffi rule:** "If you extend the `Opaque` class, you must register the extended
class using `registerOpaqueType<T>()` before using it! Also, your class MUST NOT have
type arguments."

**Project audit of `init_web.dart`:**

| Opaque subclass | Registered? | Notes |
|----------------|-------------|-------|
| `OpusEncoder` | Yes | |
| `OpusDecoder` | Yes | |
| `OpusCustomEncoder` | Yes | |
| `OpusCustomDecoder` | Yes | |
| `OpusMSEncoder` | Yes | |
| `OpusMSDecoder` | Yes | |
| `OpusProjectionEncoder` | Yes | |
| `OpusProjectionDecoder` | Yes | |
| `OpusRepacketizer` | Yes | |
| `OpusCustomMode` | Yes | |

None of the opaque types have type arguments, which satisfies that constraint.

**Verdict:** Compliant. All 10 opaque subclasses are registered exactly once.
(**Fixed** — previously `OpusRepacketizer` was registered twice and `OpusCustomMode`
was missing.)

### 12.4 No Type Checking on Function Lookups

**wasm_ffi rule:** "The actual type argument `NF` (or `T` respectively) is not used:
There is no type checking, if the function exported from WebAssembly has the same
signature or amount of parameters, only the name is looked up."

**Implication for this project:** On native `dart:ffi`, a `lookupFunction` with a
mismatched C typedef will cause a compile-time or load-time error. On `wasm_ffi`, the
C typedef is completely ignored — only the function name matters. If a Dart typedef
has the wrong number of parameters or wrong types, the call will silently pass
incorrect values to the WASM function, leading to memory corruption or wrong results
rather than a clear error.

**Project status:** The typedefs in `opus_encoder.dart` and `opus_decoder.dart` were
manually written to match the opus C API. They have been stable and match the libopus
1.5.2 API. However, there is no automated verification that these match the WASM
exports. A signature mismatch would only manifest as silent data corruption on web
while working correctly on native.

### 12.5 Return Type Constraints

**wasm_ffi rule:** Only specific return types are allowed for functions resolved via
`lookupFunction` / `asFunction`. The allowed list includes: `int`, `double`, `bool`,
`void`, `Pointer<T>` for primitive types, `Pointer<Opaque>`, `Pointer<MyOpaque>`
(if registered), and double-nested pointers `Pointer<Pointer<T>>`.

**Audit of all return types used in the project:**

| Function | Return type | Allowed? |
|----------|------------|----------|
| `opus_encoder_get_size` | `int` | Yes |
| `opus_encoder_create` | `Pointer<OpusEncoder>` | Yes (registered Opaque) |
| `opus_encoder_init` | `int` | Yes |
| `opus_encode` | `int` | Yes |
| `opus_encode_float` | `int` | Yes |
| `opus_encoder_destroy` | `void` | Yes |
| `opus_encoder_ctl` | `int` | Yes |
| `opus_decoder_get_size` | `int` | Yes |
| `opus_decoder_create` | `Pointer<OpusDecoder>` | Yes (registered Opaque) |
| `opus_decoder_init` | `int` | Yes |
| `opus_decode` | `int` | Yes |
| `opus_decode_float` | `int` | Yes |
| `opus_decoder_destroy` | `void` | Yes |
| `opus_packet_parse` | `int` | Yes |
| `opus_packet_get_bandwidth` | `int` | Yes |
| `opus_packet_get_samples_per_frame` | `int` | Yes |
| `opus_packet_get_nb_channels` | `int` | Yes |
| `opus_packet_get_nb_frames` | `int` | Yes |
| `opus_packet_get_nb_samples` | `int` | Yes |
| `opus_decoder_get_nb_samples` | `int` | Yes |
| `opus_pcm_soft_clip` | `void` | Yes |
| `opus_get_version_string` | `Pointer<Uint8>` | Yes |
| `opus_strerror` | `Pointer<Uint8>` | Yes |

**Verdict:** All return types are within the allowed set. No issues.

### 12.6 WASM Export List vs Dart Symbol Lookups

**wasm_ffi rule:** Functions must be in the WASM module's `EXPORTED_FUNCTIONS` to be
looked up. Symbols not exported will cause a runtime error on lookup.

The Emscripten build (`opus_flutter_web/Dockerfile`) exports these C symbols:

```
_malloc, _free,
_opus_get_version_string, _opus_strerror,
_opus_encoder_get_size, _opus_encoder_create, _opus_encoder_init,
_opus_encode, _opus_encode_float, _opus_encoder_destroy,
_opus_encoder_ctl,
_opus_decoder_get_size, _opus_decoder_create, _opus_decoder_init,
_opus_decode, _opus_decode_float, _opus_decoder_destroy,
_opus_packet_parse, _opus_packet_get_bandwidth,
_opus_packet_get_samples_per_frame, _opus_packet_get_nb_channels,
_opus_packet_get_nb_frames, _opus_packet_get_nb_samples,
_opus_decoder_get_nb_samples, _opus_pcm_soft_clip
```

**Dart lookups in `FunctionsAndGlobals` constructors (eager):**

| Symbol | Exported? | Lookup timing |
|--------|-----------|--------------|
| `opus_get_version_string` | Yes | Eager (constructor) |
| `opus_strerror` | Yes | Eager (constructor) |
| `opus_encoder_get_size` | Yes | Eager (constructor) |
| `opus_encoder_create` | Yes | Eager (constructor) |
| `opus_encoder_init` | Yes | Eager (constructor) |
| `opus_encode` | Yes | Eager (constructor) |
| `opus_encode_float` | Yes | Eager (constructor) |
| `opus_encoder_destroy` | Yes | Eager (constructor) |
| `opus_encoder_ctl` | Yes | Lazy (`late final`) |
| `opus_decoder_get_size` | Yes | Eager (constructor) |
| `opus_decoder_create` | Yes | Eager (constructor) |
| `opus_decoder_init` | Yes | Eager (constructor) |
| `opus_decode` | Yes | Eager (constructor) |
| `opus_decode_float` | Yes | Eager (constructor) |
| `opus_decoder_destroy` | Yes | Eager (constructor) |
| `opus_packet_parse` | Yes | Eager (constructor) |
| `opus_packet_get_bandwidth` | Yes | Eager (constructor) |
| `opus_packet_get_samples_per_frame` | Yes | Eager (constructor) |
| `opus_packet_get_nb_channels` | Yes | Eager (constructor) |
| `opus_packet_get_nb_frames` | Yes | Eager (constructor) |
| `opus_packet_get_nb_samples` | Yes | Eager (constructor) |
| `opus_decoder_get_nb_samples` | Yes | Eager (constructor) |
| `opus_pcm_soft_clip` | Yes | Eager (constructor) |

(**Fixed** — `_opus_encoder_ctl` has been added to `EXPORTED_FUNCTIONS` in the
Dockerfile. The symbol is now exported from the WASM binary and will be found when
`_opus_encoder_ctlPtr` performs its lazy lookup on first use.)

Note: the variadic ABI concern (see 12.7) is a separate issue. Exporting the symbol
ensures the lookup succeeds; whether the variadic calling convention works correctly
under WASM depends on Emscripten's ABI handling.

### 12.7 Variadic Functions Under WASM

**wasm_ffi context:** Emscripten compiles variadic C functions to WASM using a specific
ABI where variadic arguments are passed via a stack-allocated buffer. The compiled WASM
function signature may not match what a simple `lookupFunction` binding expects.

`opus_encoder_ctl` in C is:
```c
int opus_encoder_ctl(OpusEncoder *st, int request, ...);
```

The Dart binding treats it as a fixed 3-argument function:
```dart
int Function(Pointer<OpusEncoder>, int, int)
```

**Problem on WASM:** When Emscripten compiles a variadic function, the resulting WASM
function may take a different number of parameters than the Dart side expects (often a
pointer to the variadic argument buffer). Since `wasm_ffi` performs no type checking on
lookups, this mismatch would not be caught — the Dart side would call the WASM function
with the wrong number/types of arguments, causing undefined behavior.

On native `dart:ffi`, variadic function support was added in Dart 3.0 with specific
annotations. The current binding bypasses this by using `lookup` + `asFunction` directly,
which happens to work on most native platforms due to calling convention compatibility,
but is technically incorrect and non-portable.

### 12.8 Memory Growth and `asTypedList` Views

**wasm_ffi context:** The Dockerfile uses `-s ALLOW_MEMORY_GROWTH=1`. When WASM memory
grows (e.g. due to a `malloc` that exceeds the current memory size), the underlying
`ArrayBuffer` is replaced. Existing `TypedArray` views into the old buffer become
**detached** (invalid).

**Risk in this project:** The `Buffered*` implementations return `asTypedList` views:

```dart
Uint8List get inputBuffer => _inputBuffer.asTypedList(maxInputBufferSizeBytes);
Uint8List get outputBuffer => _outputBuffer.asTypedList(_outputBufferIndex);
```

If a consumer holds a reference to `inputBuffer` or `outputBuffer`, and a subsequent
allocation (e.g. creating another encoder/decoder, or any `opus.allocator.call`)
triggers WASM memory growth, the held view becomes a detached `TypedArray`. Accessing
it will throw or return garbage.

On native `dart:ffi`, `asTypedList` returns a view into process memory that remains
valid as long as the pointer is valid. This asymmetry means code that works on native
may silently break on web.

**Affected code paths:**

1. `BufferedOpusEncoder.inputBuffer` — returned to user for writing samples.
2. `BufferedOpusEncoder.outputBuffer` — returned to user after encoding.
3. `BufferedOpusDecoder.inputBuffer` — returned to user for writing packets.
4. `BufferedOpusDecoder.outputBuffer` — returned to user after decoding.
5. `BufferedOpusDecoder.outputBufferAsInt16List` / `outputBufferAsFloat32List` — cast
   views of the output buffer.
6. `StreamOpusEncoder.bind` — caches `_encoder.inputBuffer` in a local variable at the
   start of the stream, then reuses it across all iterations. If memory grows during
   the stream, this cached view is stale.
7. Any `asTypedList` call in `SimpleOpus*` encode/decode — these are short-lived
   (freed in the same `finally` block), so the risk is lower.

### 12.9 `Memory.init()` and Global Memory

**wasm_ffi rule:** "The first call you should do when you want to use wasm_ffi is
`Memory.init()`." (The README also notes this is "now automated" in newer versions.)

**Project status:** The project does **not** call `Memory.init()` explicitly. Instead,
it relies on `DynamicLibrary.open(..., useAsGlobal: GlobalMemory.ifNotSet)` to set up
the global memory. This appears to be the newer automated approach documented by
`wasm_ffi`, where `DynamicLibrary.open` handles memory initialization internally.

**Verdict:** Likely compliant with current `wasm_ffi` versions (`^2.1.0`). If the
project ever downgrades or the `wasm_ffi` API changes, the missing `Memory.init()`
could become a problem.

### 12.10 `nullptr` on Web

**wasm_ffi context:** `nullptr` in `wasm_ffi` is `Pointer.fromAddress(0)`. This
requires a valid `Memory.global` to bind to. Since the project sets global memory via
`useAsGlobal: GlobalMemory.ifNotSet`, `nullptr` should work correctly after library
loading.

**Risk:** If any code path uses `nullptr` before `initOpus()` is called (which triggers
`DynamicLibrary.open` and sets global memory), the `Pointer.fromAddress(0)` call would
throw because `Memory.global` is not set.

The project's `late ApiObject opus` global and the initialization flow (`load()` then
`initOpus()`) mean `nullptr` is only used in encoder/decoder methods that run after
init. This ordering is safe.

### 12.11 Emscripten Build Configuration Audit

Checking the Dockerfile against `wasm_ffi` requirements:

| Requirement | Status | Detail |
|-------------|--------|--------|
| `MODULARIZE=1` | Present | Required for `DynamicLibrary.open` |
| `EXPORT_NAME` | `libopus` | Matches `moduleName: 'libopus'` in Dart |
| `ALLOW_MEMORY_GROWTH=1` | Present | Required for dynamic allocation |
| `EXPORTED_RUNTIME_METHODS=["HEAPU8"]` | Present | **Required** by `wasm_ffi` for memory access |
| `_malloc` in `EXPORTED_FUNCTIONS` | Present | Required for allocator |
| `_free` in `EXPORTED_FUNCTIONS` | Present | Required for allocator |
| All used C functions exported | Yes | (**Fixed** — `_opus_encoder_ctl` was missing, now exported.) |

**Verdict:** Compliant. Build configuration is correct and all used C functions are
exported.

---

## 13. Web-Specific Risk Summary

Risks specific to the web platform, derived from cross-referencing with `wasm_ffi`
documentation:

| # | Risk | Severity | Detail |
|---|------|----------|--------|
| W1 | **`opus_encoder_ctl` not exported from WASM** | Fixed | `_opus_encoder_ctl` added to `EXPORTED_FUNCTIONS` in Dockerfile. |
| W2 | **Variadic `opus_encoder_ctl` ABI mismatch** | High | Even if exported, Emscripten's variadic function ABI may not match the Dart binding's fixed 3-arg signature. The WASM function likely expects a pointer to a variadic arg buffer, not direct arguments. |
| W3 | **`asTypedList` views detach on memory growth** | Medium | `ALLOW_MEMORY_GROWTH=1` means `malloc` can trigger buffer replacement. Held `asTypedList` views (especially in `Buffered*` classes and `StreamOpusEncoder.bind`) become invalid. |
| W4 | **`StreamOpusEncoder` caches stale buffer view** | Medium | `bind()` stores `_encoder.inputBuffer` in a local variable at stream start. If WASM memory grows during the stream, this view is detached. |
| W5 | **`OpusCustomMode` not registered** | Fixed | `registerOpaqueType<OpusCustomMode>()` was missing and `OpusRepacketizer` was registered twice. Fixed: duplicate removed, `OpusCustomMode` registered. |
| W6 | **No function signature validation** | Low | `wasm_ffi` does not validate that Dart typedefs match WASM function signatures. A typedef error would cause silent data corruption on web while working on native. |
| W7 | **`free(nullptr)` behavior unverified** | Low | After packet-loss decode, `free(nullptr)` is called. The WASM `_free` (Emscripten's `free`) should handle `NULL` safely per C standard, but this is not explicitly guaranteed by `wasm_ffi`. |
| W8 | **`Pointer[i]` indexing in `_asString`** | Fixed | `_asString` now bounds the loop to `maxStringLength` (256) and throws `StateError` if no null terminator is found, preventing unbounded WASM memory walks. |

---

## 14. Combined Risk Matrix (All Platforms)

Merging the original findings (Section 10) with web-specific findings (Section 13):

| # | Risk | Platform | Severity | Location |
|---|------|----------|----------|----------|
| 1 | ~~`opus_encoder_ctl` not exported from WASM~~ | Web | ~~**High**~~ **Fixed** | `_opus_encoder_ctl` added to `EXPORTED_FUNCTIONS` in Dockerfile |
| 2 | Variadic `opus_encoder_ctl` ABI mismatch under WASM | Web | **High** | `opus_encoder.dart:212-217` |
| 3 | ~~Use-after-destroy (no `_destroyed` check in encode/decode)~~ | All | ~~**High**~~ **Fixed** | `SimpleOpus*`, `BufferedOpus*` — all public methods now throw `OpusDestroyedError` before touching native pointers |
| 4 | ~~Output buffer sizing bug (samples vs bytes)~~ | All | ~~**High**~~ **Fixed** | `BufferedOpusDecoder` default now uses `4 * maxSamplesPerPacket`. `StreamOpusDecoder` multiplier corrected to `(floats ? 4 : 2)`. |
| 5 | `asTypedList` views detach on WASM memory growth | Web | **Medium** | `BufferedOpus*` buffer getters |
| 6 | `StreamOpusEncoder.bind` caches stale buffer view | Web | **Medium** | `opus_dart_streaming.dart:129` |
| 7 | ~~`OpusCustomMode` not registered on web~~ | Web | ~~**Medium**~~ **Fixed** | Duplicate `OpusRepacketizer` removed; `OpusCustomMode` now registered in `init_web.dart` |
| 8 | ~~Duplicate `OpusRepacketizer` registration~~ | Web | ~~**Low**~~ **Fixed** | See #7 |
| 9 | No `NativeFinalizer` — leaked memory if `destroy()` skipped | All | **Medium** | All encoder/decoder classes |
| 10 | `copyOutput = false` use-after-write | All | **Medium** | `StreamOpusEncoder`, `StreamOpusDecoder` |
| 11 | FEC double-yield overwrites with `copyOutput = false` | All | **Medium** | `opus_dart_streaming.dart:321-327` |
| 12 | Memory leak if second allocation throws | All | **Low** | `SimpleOpus*.encode/decode` |
| 13 | `free(nullptr)` behavior on web | Web | **Low** | `SimpleOpusDecoder.decode` finally |
| 14 | No function signature validation on web | Web | **Low** | All `lookupFunction` calls |
| 15 | ~~`_asString` unbounded loop~~ | All | ~~**Low**~~ **Fixed** | Now bounded by `maxStringLength`; throws `StateError` on missing terminator |
| 16 | `opus_encoder_ctl` variadic binding (native) | Native | **Low** | `opus_encoder.dart` |
| 17 | No `opus_decoder_ctl` binding | All | **Low** | `opus_decoder.dart` |
| 18 | `late` global `opus` without guard | All | **Low** | `opus_dart_misc.dart:55` |
| 19 | Linux/Windows temp dir library lifetime | Native | **Low** | Platform packages |
