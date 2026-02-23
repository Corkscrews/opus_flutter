# Code Quality

This document provides an assessment of the opus_flutter codebase's quality across multiple dimensions.

## Summary

```mermaid
quadrantChart
    title Code Quality Assessment
    x-axis Low Impact --> High Impact
    y-axis Low Quality --> High Quality
    quadrant-1 Strengths
    quadrant-2 Monitor
    quadrant-3 Low Priority
    quadrant-4 Address First
    Architecture: [0.85, 0.85]
    Code clarity: [0.6, 0.8]
    Documentation: [0.5, 0.55]
    Test coverage: [0.9, 0.4]
    Consistency: [0.4, 0.75]
    Maintainability: [0.75, 0.75]
    Build system: [0.7, 0.7]
```

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Architecture | Good | Clean federated plugin structure |
| Code clarity | Good | Small, focused files with clear intent |
| Documentation | Fair | Public APIs documented, some packages lack detail |
| Test coverage | Fair | Unit tests for platform interface and registration logic |
| Consistency | Good | Uniform patterns across all packages |
| Maintainability | Good | Clean architecture, proper plugin registration |
| Build system | Good | Modern AGP, deterministic native builds |

---

## Architecture

**Rating: Good**

The project follows Flutter's recommended federated plugin pattern correctly:

- Clear separation between the app-facing package, platform interface, and platform implementations.
- Each package has a single responsibility.
- The platform interface uses `PlatformInterface` from `plugin_platform_interface` with proper token verification.
- All platform packages self-register via `dartPluginClass` and `registerWith()`.
- A single entry point (`opus_flutter_load.dart`) delegates to the platform interface without platform-specific imports.

---

## File-by-File Analysis

### Platform Interface (`opus_flutter_platform_interface`)

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| `opus_flutter_platform_interface.dart` | 3 | Good | Clean barrel export |
| `opus_flutter_platform_interface.dart` (src) | 46 | Good | Proper PlatformInterface usage, clear docs |
| `opus_flutter_platform_unsupported.dart` | 12 | Good | Appropriate default fallback |

No issues. Well-structured.

### Main Package (`opus_flutter`)

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| `opus_flutter.dart` | 4 | Good | Single clean export |
| `opus_flutter_load.dart` | 15 | Good | Simple delegation to platform interface |

The main package is minimal by design -- it exports a single `load()` function that delegates to `OpusFlutterPlatform.instance.load()`. Platform registration is handled automatically by Flutter via `dartPluginClass`.

### Android (`opus_flutter_android`)

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| `opus_flutter_android.dart` | 19 | Good | Clean, self-registering via `dartPluginClass` |
| `OpusFlutterAndroidPlugin.java` | 14 | Good | Empty stub, expected for FFI-only plugins |
| `CMakeLists.txt` | 16 | Good | Modern FetchContent approach |
| `build.gradle` | 59 | Good | AGP 8.7.0, compileSdk 35, Java 17 |

The CMakeLists.txt is well-written and concise. The build.gradle uses AGP 8.7.0 with Java 17 compatibility. Test dependencies (`junit`, `mockito`) are included but no actual tests exist yet.

### iOS (`opus_flutter_ios`)

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| `opus_flutter_ios.dart` | 19 | Good | Clean, self-registering via `dartPluginClass` |
| `OpusFlutterIosPlugin.swift` | 8 | Good | Minimal Swift-only stub |
| `build_xcframework.sh` | 239 | Good | Well-structured, documented, error handling |

Uses Swift-only registration (no ObjC bridge). The build script is well-written with clear sections, error checking, and cleanup.

### macOS (`opus_flutter_macos`)

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| `opus_flutter_macos.dart` | 19 | Good | Clean, self-registering via `dartPluginClass` |
| `OpusFlutterMacosPlugin.swift` | 8 | Good | Minimal Swift-only stub |
| `build_xcframework.sh` | 222 | Good | Adapted from iOS script, well-structured |

Cleanest platform implementation. Uses Swift-only registration (no ObjC bridge).

### Web (`opus_flutter_web`)

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| `opus_flutter_web.dart` | 42 | Good | Most complex platform impl, uses actively maintained wasm_ffi |

The web implementation is the most involved platform package. It has to inject JavaScript, load WASM, initialize memory, and bridge through `wasm_ffi`. The migration from the unmaintained `web_ffi` to `wasm_ffi` (v2.2.0, actively maintained) has resolved the dependency risk.

### Windows (`opus_flutter_windows`)

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| `opus_flutter_windows.dart` | 57 | Good | Asset copying logic, proper arch detection via `Abi.current()` |

The Windows implementation has the most runtime logic: copying DLLs from assets to a temp directory, detecting architecture via `Abi.current()`, and loading dynamically.

### Example App

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| `main.dart` | 171 | Good | Clean demo of encoding/decoding with share functionality |

The example app demonstrates a complete encode/decode pipeline with file sharing. Code style is clean with proper return types and no unnecessary overrides. Uses vendored `opus_dart` via path dependency.

### Vendored opus_dart (`opus_dart`)

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| `opus_dart.dart` | 10 | Good | Clean barrel export |
| `proxy_ffi.dart` | 3 | Good | Conditional export: `dart:ffi` on native, `wasm_ffi/ffi.dart` on web |
| `init_ffi.dart` | 9 | Good | Native init: casts `Object` to `DynamicLibrary`, passes `malloc` as allocator |
| `init_web.dart` | 31 | Good | Web init: registers opaque types, uses `wasm_ffi` allocator. Cross-platform analysis artifacts suppressed via `ignore_for_file` |
| `opus_dart_misc.dart` | 78 | Good | Core types and `initOpus()` entry point. All fields statically typed |
| `opus_dart_encoder.dart` | 344 | Good | Simple and buffered encoder implementations |
| `opus_dart_decoder.dart` | 503 | Good | Simple and buffered decoder implementations |
| `opus_dart_packet.dart` | 95 | Good | Packet inspection utilities |
| `opus_dart_streaming.dart` | 343 | Good | Stream transformers for encode/decode pipelines |
| `wrappers/*.dart` | ~600 | Good | FFI bindings. `final` class modifier added for Dart 3 |

The vendored package required several fixes for modern Dart compatibility:

- **`dynamic` elimination:** The original code used `dynamic` for `ApiObject.allocator`, `ApiObject` constructor parameter, and the `_asString` helper. This caused `NoSuchMethodError` at runtime because `dart:ffi` extension methods (`Allocator.call<T>()`, `Pointer<Uint8>.operator []`, `Pointer<T>.asTypedList()`) cannot be dispatched through `dynamic`. All are now statically typed via `proxy_ffi.dart`.
- **`Pointer.elementAt()` removed:** Replaced with `Pointer<Uint8>` extension's `operator []` (deprecated in Dart 3.3, removed in later SDKs).
- **`wasm_ffi` 2.x API:** Corrected import paths (`ffi.dart` not `wasm_ffi.dart`), replaced `boundMemory` with `allocator`.
- **Dart 3 class modifiers:** All `Opaque` subclasses marked `final`.

---

## Dart Style and Conventions

### Positive Patterns

- Doc comments on all public APIs using `///` syntax.
- `@override` annotations used (macOS package).
- All platform packages use `dartPluginClass` for self-registration.
- Clear package naming following Flutter conventions.

### Issues Found

| Issue | Location | Status |
|-------|----------|--------|
| ~~`new` keyword used in Dart 3 codebase~~ | Various files | Resolved |
| ~~`void` return with `async`~~ | `example/main.dart` | Resolved |
| ~~Empty `initState()` override~~ | `example/main.dart` | Resolved |
| ~~Missing `@override` on `load()`~~ | Platform implementations | Resolved |
| ~~Inconsistent quote style (double vs single)~~ | `example/pubspec.yaml` | Resolved |
| ~~`dynamic` causing runtime extension method failures~~ | `opus_dart` (vendored) | Resolved |
| ~~Removed `dart:ffi` API (`Pointer.elementAt`)~~ | `opus_dart` (vendored) | Resolved |
| ~~Wrong `wasm_ffi` import paths~~ | `opus_dart` (vendored) | Resolved |
| ~~Missing `final` on `Opaque` subclasses~~ | `opus_dart` (vendored) | Resolved |

---

## Dependency Health

```mermaid
graph LR
    subgraph Low Risk
        A[plugin_platform_interface<br>^2.1.8 &#x2022; Active]
        B[flutter_lints<br>^5.0.0 &#x2022; Active]
        C[path_provider<br>^2.1.5 &#x2022; Active]
        D[share_plus<br>^10.0.0 &#x2022; Active]
        E[platform_info<br>^5.0.0 &#x2022; Active]
        H[wasm_ffi<br>^2.1.0 &#x2022; Active]
        I[ffi<br>^2.1.0 &#x2022; Active]
    end

    subgraph Medium Risk
        F[inject_js<br>^2.1.0 &#x2022; 15 months ago]
    end

    subgraph Vendored
        G[opus_dart<br>v3.0.1 &#x2022; in-repo]
    end

    style A fill:#c8e6c9,color:#000
    style B fill:#c8e6c9,color:#000
    style C fill:#c8e6c9,color:#000
    style D fill:#c8e6c9,color:#000
    style E fill:#c8e6c9,color:#000
    style F fill:#fff9c4,color:#000
    style G fill:#ce93d8,color:#000
    style H fill:#c8e6c9,color:#000
    style I fill:#c8e6c9,color:#000
```

| Dependency | Version | Last Updated | Risk |
|------------|---------|-------------|------|
| `plugin_platform_interface` | ^2.1.8 | Active | Low |
| `flutter_lints` | ^5.0.0 | Active | Low |
| `path_provider` | ^2.1.5 | Active | Low |
| `inject_js` | ^2.1.0 | 15 months ago | Medium |
| `wasm_ffi` | ^2.1.0 | Active | Low |
| `ffi` | ^2.1.0 | Active | Low |
| `opus_dart` | v3.0.1 | Vendored | None |
| `share_plus` | ^10.0.0 | Active | Low |
| `platform_info` | ^5.0.0 | Active | Low |

`opus_dart` has been vendored into the repository, eliminating it as an external dependency risk. The migration from `web_ffi` to `wasm_ffi` previously eliminated the highest-risk dependency.

---

## Build System Quality

### Android
- **Approach:** CMake FetchContent (downloads opus at build time).
- **Strength:** No vendored sources; always builds from a pinned tag.
- **Risk:** Requires internet during build; network issues or removed GitHub tags will break builds.
- **AGP:** 8.7.0 with Java 17, compileSdk 35.

### iOS
- **Approach:** Pre-built xcframework via shell script.
- **Strength:** Deterministic; no network needed at app build time.
- **Risk:** Script must be re-run manually to update opus.

### Linux
- **Approach:** Pre-built shared libraries via Docker, stored as Flutter assets.
- **Strength:** Deterministic; no network or system dependency needed at app build time. Supports x86_64 and aarch64.
- **Risk:** None significant. Uses `ubuntu:20.04` as base image (glibc 2.31 for broad compatibility). Falls back to system `libopus.so.0` if bundled binary fails.

### macOS
- **Approach:** Same as iOS.
- **Strength/Risk:** Same as iOS.

### Windows
- **Approach:** Cross-compiled via Docker, DLLs stored as assets.
- **Strength:** Deterministic; no network needed at app build time.
- **Risk:** None significant. Uses `ubuntu:24.04` as base image.

### Web
- **Approach:** Compiled via Emscripten in Docker.
- **Strength:** Deterministic output.
- **Risk:** Same Docker base image concern as Windows.

---

## Lint Coverage

| Package | Has `analysis_options.yaml` | Lint package |
|---------|----------------------------|-------------|
| opus_flutter | Yes | flutter_lints |
| opus_flutter_platform_interface | Yes | flutter_lints |
| opus_flutter_android | Yes | flutter_lints |
| opus_flutter_ios | Yes | flutter_lints |
| opus_flutter_linux | Yes | flutter_lints |
| opus_flutter_macos | Yes | flutter_lints |
| opus_flutter_web | Yes | flutter_lints |
| opus_flutter_windows | Yes | flutter_lints |
| opus_dart | Yes | `package:lints/recommended.yaml` (`constant_identifier_names` disabled for C API names) |
| example | Yes | flutter_lints |

All Flutter packages have lint configuration referencing `package:flutter_lints/flutter.yaml`. The vendored `opus_dart` is a pure Dart package and uses `package:lints/recommended.yaml` (the non-Flutter equivalent) with `constant_identifier_names` disabled since the FFI wrappers mirror upstream C API naming conventions. All files pass `dart analyze` and `dart format`.

---

## Test Coverage

| Package | Unit Tests | Widget Tests | Integration Tests |
|---------|-----------|-------------|-------------------|
| opus_flutter | 2 tests | None | None |
| opus_flutter_platform_interface | 6 tests | None | None |
| opus_flutter_android | 3 tests | None | None |
| opus_flutter_ios | 2 tests | None | None |
| opus_flutter_linux | 2 tests | None | None |
| opus_flutter_macos | 2 tests | None | None |
| opus_flutter_web | 1 test | None | None |
| opus_flutter_windows | 2 tests | None | None |
| opus_dart | 13 tests | None | None |
| example | None | None | None |

Unit tests cover the platform interface contract (singleton, token verification, version constant, error handling) and registration logic (`registerWith()`, class hierarchy) for each platform. Native library loading (`DynamicLibrary.open()`, `DynamicLibrary.process()`) cannot be unit tested as it requires the actual opus binary. CI runs all tests on every push.

The vendored `opus_dart` has 13 unit tests covering pure-logic helpers (`maxSamplesPerPacket()`, error classes, enum completeness). FFI-dependent code (encoding/decoding) requires the actual opus library and would need integration-level tests.

---

## Recommendations by Priority

### High Priority

1. ~~**Add tests**~~ -- Resolved: unit tests added for platform interface and all platform implementations.

### Medium Priority

2. ~~**Update Docker base images**~~ -- Resolved: Windows Dockerfile updated from `ubuntu:bionic` (18.04, EOL) to `ubuntu:24.04`.
3. ~~**Add `opus_dart` to CI**~~ -- Resolved: dedicated `analyze-opus-dart` and `test-opus-dart` jobs added.
4. ~~**Add `analysis_options.yaml` to `opus_dart`**~~ -- Resolved: uses `package:lints/recommended.yaml`.
5. ~~**Fix `opus_dart` formatting**~~ -- Resolved: all files pass `dart format`.
6. ~~**Add unit tests for `opus_dart` pure logic**~~ -- Resolved: 13 tests added.

### Resolved

- ~~**Add CI/CD**~~ -- GitHub Actions workflow added.
- ~~**Add `analysis_options.yaml`**~~ -- All packages have consistent lint rules.
- ~~**Evaluate web_ffi alternatives**~~ -- Migrated to `wasm_ffi` ^2.2.0.
- ~~**Check if Flutter workarounds are still needed**~~ -- Removed; all platforms use `dartPluginClass`.
- ~~**Fix Dockerfile typos**~~ -- `DEBIAN_FRONTEND` corrected.
- ~~**Simplify iOS plugin**~~ -- Swift-only, ObjC bridge removed.
- ~~**Remove `new` keyword**~~ -- Cleaned up across codebase.
- ~~**Align podspec versions**~~ -- Matched to pubspec versions.
- ~~**Add Linux support**~~ -- `opus_flutter_linux` package added.
- ~~**Vendor opus_dart**~~ -- Copied into repository, updated for Dart 3 and `wasm_ffi` 2.x.
- ~~**Fix `dynamic` dispatch crashes**~~ -- Eliminated all `dynamic` usage in `opus_dart` that caused `NoSuchMethodError` at runtime when `dart:ffi` extension methods were called through dynamic dispatch.
- ~~**Fix removed `dart:ffi` APIs**~~ -- Replaced `Pointer.elementAt()` with modern `operator []`.
- ~~**Fix `wasm_ffi` import paths**~~ -- Corrected from `wasm_ffi.dart` / `wasm_ffi_modules.dart` to `ffi.dart`.
- ~~**Dart 3 class modifier compliance**~~ -- Added `final` to all `Opaque` subclasses in wrapper files.
