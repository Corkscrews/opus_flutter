## 3.0.5

### Bug Fixes

* Fix output buffer sizing for `BufferedOpusDecoder` (was 4x too small for float output) and inverted multiplier in `StreamOpusDecoder`
* Fix `opus_encoder_ctl` variadic ABI mismatch under WASM by adding a non-variadic C wrapper
* Prevent `asTypedList` view detachment on WASM memory growth by returning Dart-heap copies
* Always copy streaming output to the Dart heap, eliminating use-after-write hazards in `StreamOpusEncoder` and `StreamOpusDecoder`
* Guard encoder/decoder methods against use after `destroy()` with `OpusDestroyedError`
* Attach `Finalizer` to encoder/decoder classes for GC-driven native resource cleanup
* Prevent memory leak when a second native allocation throws
* Add `_asString` bounds guard (cap at 256 bytes) to prevent unbounded scanning
* Register missing `OpusCustomMode` opaque type in `init_web.dart` (was duplicating `OpusRepacketizer`)
* Export `_opus_encoder_ctl` in WASM Dockerfile `EXPORTED_FUNCTIONS`

### Refactoring

* Extract duplicated encode logic into `_createOpusEncoder` and `_doEncode` / `_encodeBuffer` helpers
* Extract duplicated decode logic into shared helpers and replace magic numbers with named constants
* Deduplicate `OpusPacketUtils` with a shared `_withNativePacket` helper
* Simplify `getOpusVersion` implementation
* Add `bytesPerInt16Sample` and `bytesPerFloatSample` constants in `opus_dart_misc.dart`

### Chores

* Add `repository` field to pubspec and `CHANGELOG.md`
* Fix typos across comments and documentation
* Add RFC 6716 validation note to `maxDataBytes`
* Add comprehensive tests for buffer sizing, bounds checking, use-after-destroy, and allocation failure cleanup


## 3.0.4

* Bump version


## 3.0.3

* Depend on newer `wasm_ffi` version for web support


## 3.0.2

* libopus 1.3.1


## 3.0.1

* libopus 1.3.1


## 3.0.0

* Migrate to `opus_flutter` namespace
* Web support using [`wasm_ffi`](https://pub.dev/packages/wasm_ffi)
* libopus 1.3.1


## 2.0.1

* libopus 1.3.1
* Minor formatting fixes


## 2.0.0

* libopus 1.3.1
* Null safety support


## 1.0.4

* libopus 1.3.1


## 1.0.3

* libopus 1.3.1


## 1.0.0

* libopus 1.3.1
* Initial release
