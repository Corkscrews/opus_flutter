# Migrate libopus distribution to Dart build hooks

Reviewed against this repository and upstream documentation on 2026-10-16.
This file keeps its existing path for links, but the plan now covers all native
platforms. It describes proposed work, not an implemented migration.

## Decision

**Make build hooks and code assets the primary native distribution mechanism.**
Deliver this as the next major release of `opus_codec_dart` and `opus_codec`.
Raise the SDK baseline, consolidate native compilation in `opus_codec_dart`,
and replace platform-specific library loading with asset-bound FFI bindings.
Do not build an intermediate COpus Swift package or a new CocoaPods source pod.

Flutter recommends the `package_ffi`/build-hook approach from Flutter 3.38.
It supports Flutter and standalone Dart use without a native Flutter plugin
solely to build and load a C library.
[Flutter FFI guidance](https://docs.flutter.dev/platform-integration/bind-native-code)

The target design is:

```text
Verified, pinned upstream libopus release
                  │
          Automated source update
                  │
     opus_codec_dart pub package
     ├── vendored C sources + notices
     ├── feature/source manifest + typed CTL shim
     ├── hook/build.dart
     └── asset-bound @Native bindings
                  │
       Dart / Flutter build tooling
                  │
      Compile for the requested target
                  │
      Bundle the generated code asset
                  │
        Encode/decode through Dart
```

Compile packaged sources by default. This avoids maintaining downloadable
native release binaries and gives consumers an offline libopus build once
packages and toolchains are installed. Verified prebuilt code assets can be
added later if build time or toolchain requirements justify them; they are not
required for the first migration. Web keeps a separate WASM implementation.

Success means one native source/build owner, no manual native binary updates,
no libopus-specific CocoaPods/SwiftPM integration, and an automated upstream
update PR that prepares everything needed for release.

## Compatibility and release boundary

| Area | Decision |
|---|---|
| Dart | Raise `opus_codec_dart` to `>=3.10.0 <4.0.0` |
| Flutter | Raise the facade/example to `>=3.38.0`, with Dart `>=3.10.0 <4.0.0` |
| Package version | New major release because initialization, packaging and SDK support change |
| Older consumers | Existing 3.x releases remain available; they do not acquire hooks or automatic codec updates |
| Native platforms | One hook for macOS, iOS, Android, Linux and Windows |
| Web | Retain `wasm_ffi` and the web plugin initially; keep native bindings out of browser compilation |
| Build/link model | Bundled dynamic code asset, resolved through its asset ID |
| Codec version | First prove parity at the current 1.5.2 pin; upgrade separately after that comparison |

Stable build hooks start at Dart 3.10. Link hooks and recorded-usage
optimizations need newer SDKs and are unnecessary here; do not make them a
hidden requirement. Test the chosen package versions on the declared minimum
SDK, rather than assuming every current example works there.
[Dart hooks](https://dart.dev/tools/hooks)

Use compatible, bounded versions of `hooks`, `code_assets` and
`native_toolchain_c` as regular dependencies of `opus_codec_dart`. Use `ffigen`
as a development dependency and commit its generated bindings. Record a tested
version set and exercise dependency lower bounds in CI. A consumer must not
need `ffigen` or a separately installed binding-generation tool to build.
[Hook dependencies](https://dart.dev/tools/hooks#add-dependencies),
[hooks versions](https://pub.dev/packages/hooks/versions),
[code_assets versions](https://pub.dev/packages/code_assets/versions),
[native_toolchain_c versions](https://pub.dev/packages/native_toolchain_c/versions)

The SDK upgrade does not automatically preserve every old OS or architecture
claim. Publish a tested support matrix, including deployment targets and C
compiler requirements. In particular, the legacy Windows package contains an
x86 DLL; its existence is not evidence that the new Flutter baseline supports
Windows x86. Document any removed target explicitly. Do not claim Windows
arm64 or other new targets until tested.

Decide and publish the 3.x support policy before release: either 3.x receives
no further releases, or it receives security-only libopus updates for a stated
period. Without a decision, a libopus CVE forces an unplanned legacy rebuild
through the Docker/Xcode scripts this migration retires.

## Current state and parity baseline

Parity means matching what each platform ships **today**, not an idealised
build. The legacy builds differ per platform, so the comparison baseline does
too:

| Platform | Package / loader | Build today | Notable flags / limits |
|---|---|---|---|
| Android | `opus_codec_android`, `DynamicLibrary.open('libopus.so')` | CMake `FetchContent` of the GitHub tag archive at Gradle time (network needed) | Upstream CMake defaults, shared, `-z max-page-size=16384`; plugin `minSdk 21` |
| iOS | `opus_codec_ios`, `DynamicLibrary.process()` | Checked-in XCFramework from `build_xcframework.sh` (git clone + CMake) | `OPUS_STACK_PROTECTOR=OFF`; podspec iOS 13.0; device arm64, simulator arm64/x86_64 |
| macOS | `opus_codec_macos`, `DynamicLibrary.process()` | Checked-in versioned XCFramework (git clone + CMake) | `OPUS_STACK_PROTECTOR=OFF`; podspec macOS 10.14; arm64/x86_64 universal |
| Linux | `opus_codec_linux`, copies `.so.blob` to temp dir, falls back to system `libopus.so.0` | Docker, Ubuntu 20.04 GCC, x86_64 + aarch64 cross | `OPUS_DISABLE_INTRINSICS=ON`, `OPUS_STACK_PROTECTOR=OFF`, glibc floor of Ubuntu 20.04 |
| Windows | `opus_codec_windows`, copies `.dll.blob` + licence to temp dir | Docker, MinGW autotools, x64 + x86 | Autotools defaults (RTCD on); MinGW runtime, not MSVC |
| Web | `opus_codec_web`, `wasm_ffi` | Docker Emscripten, static lib + `opus_ctl_wrapper.c` | `OPUS_DISABLE_INTRINSICS=ON`; explicit `EXPORTED_FUNCTIONS` list |

Consequences for the migration:

- Generic C is **not** a regression on Linux and web; it is the current build.
  SIMD parity only matters where the legacy build had it (Android, Apple,
  Windows RTCD).
- Windows moves from a MinGW DLL to an MSVC-built DLL through
  `native_toolchain_c`. Treat that as a toolchain change: re-check exports,
  CRT linkage, RTCD/SIMD and performance rather than assuming equivalence.
- Linux's glibc floor changes from "Ubuntu 20.04 build host" to "the consumer's
  compiler and sysroot". Document that the library now matches the app's own
  build environment.
- Android no longer needs network access at Gradle time, but gains the hook's
  ABI list from Flutter instead of the plugin's Gradle configuration.

### Version pin inventory

Every one of these carries `1.5.2` today and must move to the manifest, be
generated from it, or be deleted with the legacy path:

- `build_opus.sh` (`OPUS_VERSION`, label only)
- `opus_flutter_ios/ios/build_xcframework.sh`, `opus_flutter_macos/macos/build_xcframework.sh`
- `opus_flutter_android/android/CMakeLists.txt`
- `opus_flutter_linux/Dockerfile`, `opus_flutter_windows/Dockerfile`, `opus_flutter_web/Dockerfile`
- `OpusFlutterPlatform.opusVersion` and its test in `opus_flutter_platform_interface`
- `README.md`, `opus_flutter/README.md`, `opus_dart/README.md`
- `docs/architecture.md` (and historical mentions in `docs/ffi-analysis.md`, `docs/issues-and-improvements.md`)

Replace the hard-coded `opusVersion` constant with a value generated from the
manifest into `opus_codec_dart` (or remove it in favour of `getOpusVersion()`),
and have CI assert that the generated constant, the manifest and the runtime
version string agree on every platform, including web.

### Native symbol surface

Only `libinfo`, `encoder` and `decoder` are wired into `ApiObject`. The bound
functions are exactly those in the web `EXPORTED_FUNCTIONS` list: version and
error strings, encoder get_size/create/init/encode/encode_float/destroy/ctl,
decoder get_size/create/init/decode/decode_float/destroy, the `opus_packet_*`
helpers, `opus_decoder_get_nb_samples` and `opus_pcm_soft_clip`. The
`opus_custom`, `opus_multistream`, `opus_projection` and `opus_repacketizer`
wrapper files only declare opaque types today.

Make that list the explicit ABI contract for the first release: generate
bindings for it, test every entry, and keep multistream/projection/repacketizer
out of the public Dart surface unless separately designed. Custom modes stay
disabled (`CUSTOM_MODES` undefined), so no `opus_custom_*` binding may be
generated against the shipped asset.

## Why this fixes the macOS problem

The current macOS builder creates a versioned framework with symlinks. The
previous investigation recorded Xcode rejecting a flat framework and signing
failing after the versioned framework's links were dereferenced. Pub's archive
writer copies link targets, so shipping that framework directly as pub files
is unreliable. These failures were not rerun during this document review.
[Pub archive implementation](https://github.com/dart-lang/pub/blob/master/lib/src/io.dart)

The new pub payload contains ordinary sources and metadata. Flutter packages
the generated native asset during the application build, including Apple
framework handling. No prebuilt versioned framework crosses the pub archive
boundary. Framework generation/signing still requires release validation;
build hooks do not make those checks unnecessary.
[Flutter asset packaging](https://docs.flutter.dev/platform-integration/bind-native-code#dynamic-library-naming-guidelines)

## Package ownership and cleanup

Make `opus_codec_dart` the sole owner of native libopus sources, configuration,
bindings and the build hook. Keep it usable without Flutter. Make `opus_codec`
a thin Flutter-facing initialization facade that depends on `opus_codec_dart`
and retains web plugin integration.

Proposed layout; names below are implementation targets, not existing files:

```text
opus_dart/                         # pub package: opus_codec_dart
├── pubspec.yaml
├── hook/
│   └── build.dart                 # sole native build entry point
├── native/
│   ├── libopus.json               # canonical version, digest, feature policy
│   ├── build_config.dart          # target selection and compiler settings
│   ├── sources.json               # generated source groups/allowlists
│   ├── shim/                      # fixed-signature, exported CTL wrappers
│   └── vendor/opus/               # unmodified upstream sources and notices
├── lib/src/native/
│   ├── opus_bindings.dart         # generated @Native declarations
│   └── api_adapter.dart           # existing codec interfaces → native bindings
├── lib/src/                       # codec API + conditional native/web init
└── test/

scripts/
└── update_libopus.dart            # maintainer/CI regeneration, not an app hook

opus_flutter/                      # pub package: opus_codec
└── lib/                           # unified initialization facade

opus_flutter_web/
├── assets/                        # generated JS/WASM, versioned with sources
└── ...                            # existing web registration/loading
```

Everything read by the hook must be inside `opus_codec_dart`'s pub archive.
The updater may live at repository root because consumers never run it. Have
web build tooling read the same canonical manifest, or generate and check a
package-local copy where required; do not maintain independent version pins.

After the new integration passes on all intended platforms:

- Remove the Android/iOS/macOS/Linux/Windows packages from the facade's
  dependencies and `default_package` declarations. Remove their overrides from
  the example so an old plugin cannot mask missing code assets.
- Retire their XCFrameworks, `.blob` assets, native build scripts and loaders
  from the active release path. Previously published packages remain available.
- Remove libopus-specific runtime extraction, temporary-file reuse and
  Linux's implicit system-library fallback. Missing assets must fail clearly.
- Update `scripts/common.sh`, analysis/test/publish package lists,
  `prepare_publish.dart` usage, CI, READMEs and examples for the new graph.
  Publish the core before the facade. Retain the web/platform-interface
  packages while web still uses them.
- Replace the native tasks in `build_opus.sh` with hook-backed validation or
  remove them. Retain a clearly named WASM build command.
- Delete the Linux, Windows, iOS and macOS Dockerfiles/XCFramework scripts and
  the Android `CMakeLists.txt`/Gradle native build once their packages leave the
  release graph. Keep only the web Dockerfile, pointed at the vendored sources
  instead of `git clone`.
- Regenerate the example's platform files after removing the plugins: the
  macOS/iOS `Podfile.lock`, `GeneratedPluginRegistrant.swift`, and the Linux and
  Windows `generated_plugins.cmake`/registrants must no longer list
  `opus_codec_*` native plugins. Drop the example's `dependency_overrides` for
  removed packages and migrate `lib/main.dart` to the new initialization.
- Update `docs/architecture.md`, `docs/ffi-analysis.md`, every package README
  and CHANGELOG to describe the hook design; mark superseded sections of
  `docs/issues-and-improvements.md` rather than leaving contradictory status.
- After the new major is stable, mark the native platform packages
  discontinued on pub.dev with `opus_codec` as the replacement, so tooling warns
  users who still depend on them directly.

Do not load both legacy plugin binaries and the new asset in the same app.
Development can proceed platform by platform, but release one coherent native
backend rather than a permanent mixture of hooks and legacy loaders.

## Build-hook contract

Use `native_toolchain_c` to compile the explicit source set for the target
requested by the SDK. It invokes a suitable C compiler; it does not translate
libopus's CMake configuration automatically or install every required toolchain.
[C builder API](https://pub.dev/documentation/native_toolchain_c/latest/native_toolchain_c/CBuilder-class.html)

The hook must:

1. Check whether the invocation requests code assets before reading native
   target configuration. Return without native compilation for invocations
   that do not request them, including browser builds as applicable. Fail
   clearly for unsupported requested native targets.
2. Select sources, defines, includes and flags using the requested OS,
   architecture, SDK and deployment/API target. Never select by the host's
   `Platform.operatingSystem` when cross-compiling. Respect the compiler
   configuration supplied by the SDK.
3. Compile libopus and the package-owned shim into one bundled dynamic library.
   Publish one stable code asset ID:
   `package:opus_codec_dart/src/native/opus_bindings.dart`.
   Bind that ID to the generated file with the bundled-dynamic link mode.
4. Use a distinctive library basename such as `opus_codec`, consistent across
   architectures and Apple device/simulator builds. Put outputs in the
   invocation-specific output directory, not the source tree or pub cache.
   Keep the asset ID set consistent between slices.
5. Register all non-Dart build inputs that affect output, including headers,
   source inventories, the version manifest and configuration. Verify cache
   invalidation when any input changes. Do not assume listing `.c` files alone
   covers headers and generated metadata.
6. Run offline against the shipped sources, with no `git clone`, moving version
   lookup, package-cache modification or libopus download. Report missing
   compilers/toolchains with actionable errors.

These are behavioral requirements. Implement against the selected package
versions; do not mix old `native_assets_cli`, current hook APIs and newer SDK
examples into an untested code snippet.
[Target configuration](https://pub.dev/documentation/code_assets/latest/code_assets/CodeConfig-class.html),
[bundled code assets](https://pub.dev/documentation/code_assets/latest/code_assets/CodeAsset-class.html),
[hook inputs and dependencies](https://dart.dev/tools/hooks)

Consumers need Xcode/Apple SDKs on Apple platforms, the Android NDK for Android,
and a supported C toolchain on Linux/Windows. Standalone Dart users also acquire
a C compiler requirement under this default. So do consumers' host-side
`flutter test`/`dart test` jobs, which run the hook for the host OS: a CI image
that today runs widget tests without a C compiler will fail after upgrading.
State this prominently in the migration guide. CI should exercise ordinary
consumer environments without Docker or CMake installed unless the documented
implementation actually requires them.

## Sources, configuration and CPU optimizations

Vendor a verified official release archive. Record its URL, SHA-256, version,
source inventory and generator identity in the package. Parse upstream source
lists as data, preserve notices and unmodified upstream files, and regenerate
an explicit allowlist. Reject missing, duplicate, unexpected or escaping paths.
Do not compile all `**/*.c`, which would include alternatives, demos and tests.
[Upstream source groups](https://github.com/xiph/opus/blob/v1.5.2/cmake/OpusSources.cmake)

For the initial 1.5.2 comparison, use the generic CELT/SILK/Opus groups plus
`SILK_SOURCES_FLOAT` and `OPUS_SOURCES_FLOAT`, then add target-specific optimized
groups deliberately. Keep fixed-point and optional DNN features disabled for
that baseline. Preserve integer and float public APIs.

Generate and audit configuration per target/toolchain. In 1.5.2 CMake's
`config.h` contains only version metadata; most definitions come from compiler
settings. Compare reference `compile_commands.json`, generated headers and
cache settings, including allocation, runtime dispatch, visibility and
hardening. `OPUS_FLOAT_APPROX` defaults off and `OPUS_HARDENING` on. Keep
stack-protector policy separate from Opus's own runtime hardening. Do not reuse
an Apple header unchanged on Windows or Android.
[Config template](https://github.com/xiph/opus/blob/v1.5.2/cmake/config.h.cmake.in)
and [upstream CMake configuration](https://github.com/xiph/opus/blob/v1.5.2/CMakeLists.txt)

Hooks select one target per invocation, so the earlier universal-build
workaround using architecture-guarded SwiftPM wrappers is no longer the
starting point. Use arm64 NEON where supported and preserve useful Intel SIMD
where feasible. Optional instruction sets such as AVX2 require correct runtime
dispatch and per-source/object-group flags; never enable them globally just
because the build host supports them. Separate compilation steps may be needed
beyond a single C builder invocation. Generic C is acceptable for the first
prototype, but a release needs measured performance against the current build.

Ensure exported functions remain visible in release output. Include Windows
export definitions (`OPUS_BUILD`/`DLL_EXPORT` as applicable) and explicitly
export the shim there as well. Respect Android page-size alignment, platform
minimums, Windows runtime linkage and Linux libc compatibility. A single hook
centralizes these settings; it does not erase their differences.
[Opus export definitions](https://github.com/xiph/opus/blob/v1.5.2/include/opus_defines.h)

Build with hidden default visibility and `OPUS_BUILD` so only `OPUS_EXPORT`
functions and the shim are exported. On ELF targets (Linux, Android) also bind
internal references locally (`-Wl,-Bsymbolic` or equivalent, with hidden
visibility for everything else). Otherwise, if another library in the process
already exports `opus_*` symbols, calls *inside* our library — including the
shim's call to `opus_encoder_ctl` — can be interposed onto that other libopus
even though Dart resolved the entry point correctly. Apple's two-level
namespace and Windows DLL imports do not have this problem, but verify them
in the coexistence test anyway.

### Vendored subset, size and line endings

The upstream 1.5.2 release archive includes DNN model data, tests, docs and
build-system files that the baseline does not compile. Vendor only the files
the allowlist needs, plus headers, `COPYING`, `AUTHORS` and other notices.
"Unmodified" means each vendored file is byte-identical to the verified
archive, not that the whole archive is shipped. Record the pruned set in the
manifest so the updater can prove nothing required was dropped. Track the
published package size; it affects every consumer's `pub get` and must stay
well inside pub.dev's archive limit.

The root `.gitattributes` sets `* text=auto`, which can rewrite line endings
of vendored C files on Windows checkouts and break digest verification. Mark
the vendor tree `-text` (or verify digests against normalized content) and
exclude it from `dart format`/analysis scripts.

### Licensing

Flutter's licence page collects each package's top-level `LICENSE`. Once
libopus is compiled from `opus_codec_dart`, append the libopus BSD licence
(from upstream `COPYING`) to `opus_dart/LICENSE`, keep the full notices in the
vendor tree, and confirm pub.dev still detects the package licence. This
replaces the `opus_license.txt` the Windows package copies at runtime. Check
the final app's licence page lists libopus on every platform.

## FFI and initialization migration

### Asset-bound bindings

The current `initOpus(Object)` constructs wrappers around a `DynamicLibrary`.
Native loaders return either `DynamicLibrary.process()` or a manually opened
file. Adding a hook without changing those bindings is incomplete.

Generate native-only `@Native` declarations associated with the code asset.
For example, the binding shape for version reporting is:

```dart
import 'dart:ffi';

@Native<Pointer<Char> Function()>(
  assetId: 'package:opus_codec_dart/src/native/opus_bindings.dart',
  symbol: 'opus_get_version_string',
)
external Pointer<Char> opusGetVersionString();
```

The asset identifier must exactly match the hook output. Use it consistently
for every native declaration, directly or through a library-wide default.
Explicit asset mapping avoids relying on process-wide symbol discovery; still
verify the shipped asset is the provider and a missing mapping cannot be
masked by another libopus already loaded into the process.
[Native binding resolution](https://api.dart.dev/dart-ffi/Native-class.html)

Adapt these functions to the existing encoder/decoder/libinfo interfaces so
high-level codec classes and mock-based tests remain useful. Add a production
constructor for the native backend rather than passing it through an API that
still casts its argument to `DynamicLibrary`. Retain conditional imports:
web continues using its WASM bindings and allocator. Never expose `dart:ffi`
annotations to the browser compilation path.

### Typed CTL bridge

Treat CTL migration as required ABI work. The current encoder wrapper tries
`opus_encoder_ctl_int` and falls back to binding variadic `opus_encoder_ctl`
with a fixed three-argument signature. The web package already uses a C shim.
Do not carry that native fallback into the new backend: variadic calling
conventions need correct handling across targets.
[Dart variadic FFI](https://api.dart.dev/dart-ffi/VarArgs-class.html)

Compile fixed-signature, uniquely prefixed C wrappers with libopus. Preserve
currently supported integer-setting CTLs; add separate pointer-result or
no-argument wrappers only for supported operations. Validate request types so
a getter cannot accidentally receive an integer where a pointer is required.
Never pass a pointer through a Dart/C `int` surrogate. The existing web shim
exports the unprefixed `opus_encoder_ctl_int`; if the shared shim renames it,
update the Emscripten `EXPORTED_FUNCTIONS` list and the web binding in the same
change, and drop the raw variadic `_opus_encoder_ctl` export once unused.
Share the shim with the WASM build where useful, and test CTLs on Apple arm64 and Windows as well as
Linux. Keep allocation/free pairs in their owning runtime, including Opus
create/destroy functions and the WASM allocator.

### Public migration

Use a new facade initialization entry point. Proposed consumer change:

```dart
// Before:
initOpus(await opus_codec.load());

// After:
await opus_codec.initializeOpus();
```

On native platforms the facade initializes the asset-backed core, without
returning a library handle. On web it loads the existing WASM backend and
initializes the core with that backend. Provide `initOpus()` without a library
argument for native standalone Dart use. Define repeated initialization and
per-isolate behavior; do not replace a backend while live codec objects exist.

Make the entry points explicit per environment:

| Environment | Today | New major |
|---|---|---|
| Flutter native | `initOpus(await opus_codec.load())` | `await opus_codec.initializeOpus()` |
| Flutter web | same call, WASM library from `opus_codec_web` | same `initializeOpus()`, WASM backend inside the facade/web plugin |
| Dart native (no Flutter) | caller opens a `DynamicLibrary` and calls `initOpus(lib)` | `initOpus()`; asset resolved by the hook |
| Dart web (no Flutter) | caller loads a `wasm_ffi` library and calls `initOpus(lib)` | keep a web-only entry point that accepts the `wasm_ffi` library |

Do not drop the last row by accident: removing the `Object` parameter from
`initOpus` everywhere would leave non-Flutter web users without an API.

The breaking-change list for the migration guide must cover at least:
`opus_codec.load()`, `OpusFlutterPlatform.load()` on native platforms,
`initOpus(Object)` on native, the public `FunctionsAndGlobals(DynamicLibrary)`
constructors in `package:opus_codec_dart/wrappers/*.dart` (importable today
even though the README treats them as internal), `OpusFlutterPlatform.opusVersion`
if removed, the SDK floor, and the removed platform packages.

Remove the native `load() -> DynamicLibrary` contract in the new major and
provide a migration guide. Do not fabricate a library path or return a dummy
handle to preserve its signature. If explicit caller-supplied libraries remain
supported, expose a separate deliberate API and test it; do not silently
fallback to a system installation. That optional feature must not block the
standard asset-backed migration.

## Web remains a separate backend

Native code assets do not replace the current JS/WASM distribution. Keep web
registration, loading, opaque types and allocator behavior working while the
native path changes. Browser builds must not invoke a native C compiler or
attempt to load the native asset.

Use the same pinned upstream release and applicable feature policy for WASM.
The update pipeline must rebuild and commit/release the JS/WASM pair together,
verify `getOpusVersion()` in a browser, and run codec/CTL tests. A native-only
version bump with stale WASM assets is an incomplete dependency update.

## Implementation and release gates

### Implementation sequence

1. **Establish the new major baseline.** Update SDK constraints, dependency
   graph and CI's minimum/latest matrix. Keep legacy releases accessible and
   document the SDK/initialization break. The existing macOS packaging issue
   remains a reason for old consumers to upgrade, not a promise of a 3.x fix.
2. **Build the macOS vertical slice.** Vendor 1.5.2, add the hook, asset bindings,
   CTL shim and adapter, and run real release encode/decode from an extracted
   package. Verify arm64 and x86_64; prove no legacy plugin supplies the symbols.
3. **Expand the same hook.** Validate iOS, Android, Linux and Windows, with
   explicit source/configuration choices and toolchain diagnostics. Finish web
   conditional initialization and standalone Dart coverage.
4. **Remove the legacy integration.** Clean dependency declarations, binaries,
   scripts, package lists and documentation. Test an application migrating from
   3.x as well as fresh consumers. Keep one native backend in the release graph.
5. **Automate upstream updates.** Add the pipeline below and use a separate
   codec-upgrade PR after baseline parity. Upstream currently lists 1.6.1;
   do not embed a moving latest-version lookup in consumer builds.
   [Opus releases](https://opus-codec.org/downloads/)
6. **Release the tested payload.** Publish core, any updated web dependencies,
   then facade in dependency order. Verify the actual hosted archives and
   consumer migration before announcing the new major.

### Package fidelity

`pub publish --dry-run` validates but does not provide a supported reusable
archive export. Stage rewritten publish metadata in a disposable directory;
create a test archive from the exact pub-selected files, using a pinned/tested
packaging helper, and extract it away from the checkout. Include `hook/`, its
helper code, source/header inventory, manifests, shim and all relevant notices.
Reject required files outside the package, symlinks and leftover native blobs.
[Pub publishing command](https://dart.dev/tools/pub/cmd/pub-lish)

Test with an isolated cache and dependencies resolving only to extracted
packages or published dependencies. Inspect `package_config.json`; no override
may point back to the working tree. Run both minimum and latest SDK consumers.
After an intentional prerelease, repeat using its actual pub.dev archive.
Do not publish disposable prereleases on every CI run.

### Required validation

| Check | Acceptance criterion |
|---|---|
| SDK/dependencies | Minimum Flutter 3.38/Dart 3.10 and latest supported stable; selected hook dependencies resolve and run on both |
| macOS | arm64/x86_64 builds and runtime coverage, release/AOT, signing and launch; exactly the intended libopus asset |
| iOS | Device arm64 and supported simulator architectures; release device run and distribution archive/signing validation |
| Android | Each advertised ABI/API baseline; release APK/AAB inspection and codec execution, including applicable 16 KB page-size checks |
| Linux/Windows | Build and run each advertised target with documented toolchains; no temporary extraction or accidental system-library fallback |
| Standalone Dart | `dart run`, real native `dart test`, and a supported AOT executable plus its required asset distribution |
| Web | Browser build/run, WASM version and codec/CTL tests; no native FFI imports or compiler dependency |
| Codec ABI | Version, all shipped bindings, integer/float audio, mono/stereo, CTLs, errors, lifecycle and allocator ownership |
| Packaging | Extracted publish payload and hosted candidate work without checkout files; no legacy plugin present |
| Caching/offline | A clean source build works without libopus network access; edits to sources, headers or manifest invalidate cached output |
| Performance | Measured encode/decode throughput, app/package size and clean/incremental build time against the legacy baseline |
| Coexistence | Another dependency's libopus cannot silently satisfy missing bindings, nor interpose calls inside our library; the resolved provider/version is verified |
| Licensing | Final app licence page lists libopus; vendored notices present in the extracted package |
| Debug symbols | Release builds strip as intended; Apple dSYMs and Android native debug symbols are produced or the gap is documented |

Cross-compilation alone does not count as runtime coverage. Record any missing
hardware/test coverage and narrow support claims accordingly. Use aligned,
tolerance-based comparisons for lossy PCM and retain exact/conformance checks
where appropriate. Mock tests and a successful debug build are insufficient.

Inspect exported symbols, architecture slices, dependencies and deployment
metadata in the **final application**, not only the intermediate library.
On macOS verify with `codesign --verify --deep --strict --verbose=2`, then launch.
Test normal release stripping and native-asset packaging. Also exercise SwiftPM
and CocoaPods app configurations while Flutter supports both, proving libopus
itself no longer depends on either integration path.

Concrete CI changes in `.github/workflows/ci.yml`:

- Move the `oldest` matrix entry from Flutter 3.27.0 to 3.38.0 and delete the
  mockito/analyzer override and the minSdk/Gradle patches that only exist for
  the old floor (re-check which are still needed).
- Add real-native `dart test` for `opus_codec_dart` on Linux, macOS and Windows
  runners; today only mock tests run, on Linux.
- Turn example builds into release builds that also *run* a codec smoke test:
  macOS and Windows natively, Linux under a virtual display, Android emulator,
  iOS simulator. Debug `--no-codesign` builds alone are not acceptance.
- Add a binding drift check: regenerate `ffigen` output and the version
  constant from the committed config and fail on any diff.
- Add a manifest `--check` job that re-verifies vendored file digests.

Make `.github/workflows/publish.yml` require these checks for the exact revision
and payload being published. It currently only gates publication with Linux
analysis/unit tests. Preserve a reproducible previous release and stop the
update/release pipeline when a gate fails; never substitute an arbitrary
system library or publish partially updated platform artifacts.

## Alternatives and boundaries

- **COpus with SwiftPM/CocoaPods:** fallback only if a demonstrated hook blocker
  cannot be resolved. It adds an Apple-specific integration to maintain and
  does not consolidate the other native platforms. It is no longer planned work.
- **Verified prebuilt assets through the same hook:** optional later
  optimization. Use immutable artifacts and checksums committed in the package,
  target-specific selection, cache/offline behavior and the same ABI tests.
  CI must produce them automatically; downloading binaries does not remove
  release maintenance or provenance requirements.
- **Running upstream CMake from the hook:** possible if complex source/flag
  selection makes it worthwhile, but adds a consumer build-tool dependency.
  Start with `native_toolchain_c`; adopt CMake only with measured benefit and
  documented toolchain setup.
- **Link hooks/static retention tuning:** defer unless a concrete requirement
  warrants the additional SDK floor and testing. Bundled dynamic assets are
  the first release contract.

## Automatic libopus updates and maintenance effort

**The intended steady state is no manual source copying and no local native
binary rebuilding.** Xiph releases the codec, a bot prepares a complete update,
CI validates it, and the maintainer reviews/releases. Apps obtain the update
through a new package release and rebuild; hooks do not update installed apps
or automatically follow upstream.

The current repository duplicates `1.5.2` across Apple scripts, Android CMake,
Dockerfiles, the platform-interface constant, READMEs and docs (see the
version pin inventory). The root script's version variable only labels output. Moving
to one packaged source manifest eliminates that drift for native targets;
WASM generation must join the same update transaction.

### Maintainer-side pipeline

1. **Detect:** a scheduled GitHub Actions workflow, with manual dispatch, checks
   official stable libopus releases. Deduplicate by version and exclude
   prereleases. Renovate's custom manager is an optional detector, not the
   complete regeneration solution.
2. **Verify and vendor:** retrieve the immutable release archive, verify its
   expected SHA-256, regenerate the source/configuration inventory, preserve
   notices and refresh version metadata. Provide a deterministic `--check` mode.
   Unknown source groups, changed configuration or missing files fail for review.
3. **Regenerate bindings and WASM:** update generated native bindings against
   the pinned headers/shim and rebuild JS/WASM together. Keep changes to the
   public Dart API deliberate; a new C API does not automatically become public.
4. **Validate:** run the full packaged hook matrix, upstream codec tests where
   applicable, real FFI tests and browser tests. Compile native test artifacts
   in CI; do not check native binaries into the new pub packages.
5. **Open one complete PR:** include release notes, version/digest, configuration
   and binding changes, source inventory, WASM hashes and test results. No
   manual copying or native XCFramework/DLL build should remain for the reviewer.
6. **Release:** update affected package versions/changelogs, merge after checks,
   and publish the tested revision in dependency order. Begin with reviewed
   releases; automate patch merges/publication only after the gates are proven.

Run source builds without write/publish credentials. Separate the narrowly
privileged PR job from build jobs and the release job. Pin workflow dependencies
and do not run untrusted PR code with privileged `pull_request_target` access.
A checksum makes content reproducible; it does not establish that new upstream
code is safe without review and testing.

Ensure bot updates trigger validation on their generated commit. A scoped
GitHub App token or explicit dispatch can avoid relying on `GITHUB_TOKEN` push
behavior. If using Renovate, its post-upgrade commands require host permission;
repository configuration alone does not guarantee regeneration runs.
[GitHub trigger rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow),
[Renovate custom managers](https://docs.renovatebot.com/modules/manager/regex/),
[Renovate post-upgrade tasks](https://docs.renovatebot.com/configuration-options/#postupgradetasks)

### How easy will updates be?

| Work | Expected effort |
|---|---|
| Initial migration | Substantial one-time work: native binding adapter, CTL ABI, source configuration, SDK/API break and cross-platform release tests |
| Routine compatible libopus release | Low maintainer effort after automation: review a generated, tested PR and release |
| Source-list, compiler or feature changes | Manual investigation/configuration changes; the bot must stop rather than guess |
| Web update | Automated WASM build remains necessary even though native binaries are no longer maintained |
| Fully unattended releases | Possible later, but still requires ownership of failed updates and compatibility/security review |

These are scope estimates, not measured delivery times. The cost is front-loaded
into the migration and CI; subsequent updates should not require a maintainer's
local Xcode, Docker or binary-copying session.

Xiph does not need to adopt SwiftPM or build hooks for this design: we consume
its released source through one automated adapter. Asking another project to
own that adapter would require agreement and would transfer, not remove,
maintenance. This repository remains responsible for its Dart compatibility
and releases, while the repetitive dependency work becomes automated.

This document change enables no schedule, changes no package SDK constraint,
and publishes nothing. Implementing the plan should deliver the hook migration
and updater together so the new architecture also solves manual Opus upkeep.
