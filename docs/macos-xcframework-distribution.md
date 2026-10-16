# Building libopus from source on macOS

This document describes why `opus_codec_macos` can't be built from its pub.dev
package with recent Xcode versions, and proposes replacing the prebuilt
framework with libopus compiled from source, following the approach used by
`sqlite3_flutter_libs`.

## Problem

`opus_codec_macos` ships libopus as a prebuilt dynamic framework inside
`macos/opus_codec_macos/opus.xcframework`. The Dart side looks up opus symbols
with `DynamicLibrary.process()`, so the framework must be linked into, and
embedded in, the app.

Two constraints conflict:

1. **Xcode requires the deep bundle layout on macOS.** Up to 3.1.0 the framework
   used the flat iOS layout (`Info.plist` at the root). Current Xcode rejects
   it when embedding:

   ```
   error: Framework .../opus.framework contains Info.plist, expected
   Versions/Current/Resources/Info.plist since the platform does not use shallow bundles
   ```

   The deep layout puts the content in `Versions/A` and relies on symlinks
   (`Versions/Current -> A`, plus `opus`, `Headers`, `Modules` and `Resources`
   at the root).

2. **pub.dev archives can't carry symlinks.** `pub publish` follows symlinks and
   stores copies of their targets, so the published package contains
   `Versions/Current` and the root entries as real directories. Xcode then
   fails:

   ```
   warning: Couldn't resolve framework symlink for '.../opus.framework/Versions/Current'
   Command CodeSign failed with a nonzero exit code
   ```

   This was reproduced locally by copying the framework with `cp -RL` (which
   dereferences symlinks, as pub does) and building the example app.

| Source of the package | Flat layout (≤ 3.1.0) | Deep layout (current `master`) |
|---|---|---|
| git / path dependency | ❌ rejected by Xcode | ✅ builds and signs |
| pub.dev | ❌ rejected by Xcode | ❌ symlinks lost, signing fails |

Any prebuilt macOS framework has this problem when it's published through pub.
The fix is to stop shipping one.

## How sqlite3_flutter_libs solved this

`sqlite3_flutter_libs` 0.5.x (the last release before it was retired, 0.5.42)
shipped no SQLite binary for iOS and macOS. Its plugin was an empty Swift class
whose only job was to make the app link SQLite, which was compiled from source
by the app's own build:

- **Swift Package Manager:** the plugin's `Package.swift` depended on
  [`CSQLite`](https://github.com/simolus3/CSQLite), a package containing only
  `sqlite3.c`, its headers, and the compile-time defines. `CSQLite` declares its
  product as `type: .dynamic`, so SQLite is linked as its own dynamic library
  and its symbols stay exported.
- **CocoaPods:** the podspec depended on the `sqlite3` source pod from the
  CocoaPods trunk, with subspecs selecting compile-time options.

Dart then found the symbols in the running process. Because the library was
compiled by Xcode as part of the app, there was never a bundle to package or a
symlink to lose.

The same project later replaced this with Dart
[build hooks](https://dart.dev/tools/hooks) in `package:sqlite3` 3.x (see
[Later: build hooks](#later-build-hooks)).

## Proposed solution

Replace `opus.xcframework` with the libopus sources, compiled by SwiftPM or
CocoaPods as part of the app build. The plugin keeps its current Swift class and
Dart API. Only how libopus gets into the app changes.

Two parts of the sqlite3 design can't be copied as-is:

- **libopus has no single-file amalgamation.** It's around 200 C files split
  across `celt/`, `silk/` and `src/`, plus architecture-specific files that need
  special compiler flags (NEON on ARM, SSE/AVX on x86).
- **CocoaPods trunk is going read-only,** so publishing a new libopus source pod
  isn't a viable long-term path. The sources ship inside the plugin package
  instead and both build systems compile the same files.

### Package layout

```
opus_flutter_macos/macos/
├── opus_codec_macos.podspec
├── vendor_libopus.sh            # replaces build_xcframework.sh
└── opus_codec_macos/
    ├── Package.swift            # plugin package, depends on COpus
    ├── Sources/opus_codec_macos/OpusFlutterMacosPlugin.swift
    └── COpus/                   # local SwiftPM package, like CSQLite
        ├── Package.swift
        └── Sources/COpus/
            ├── config.h         # replaces the CMake-generated config
            ├── include/         # opus.h, opus_defines.h, … + module.modulemap
            ├── celt/ silk/ src/ # upstream libopus sources, unmodified
            └── arch/            # wrappers for architecture-specific files
```

`COpus` lives inside the plugin and is referenced with
`.package(path: "COpus")`, so nothing is fetched over the network, and git and
pub.dev users get the same files.

### Vendoring script

`vendor_libopus.sh` replaces `build_xcframework.sh`. It:

1. Clones libopus at a pinned tag (`v1.5.2`, matching today's build).
2. Reads the upstream source lists (`celt_sources.mk`, `silk_sources.mk` and
   `opus_sources.mk`) instead of hard-coding file names. It copies the generic
   sources plus the float variants (`SILK_SOURCES_FLOAT`,
   `OPUS_SOURCES_FLOAT`), matching the current CMake build's floating-point
   configuration.
3. Copies the ARM NEON intrinsics files (`CELT_SOURCES_ARM_NEON_INTR` and
   `SILK_SOURCES_ARM_NEON_INTR`) and generates one wrapper per file in `arch/`:

   ```c
   #if defined(__aarch64__)
   #include "../celt/arm/celt_neon_intr.c"
   #endif
   ```

   Neither SwiftPM nor CocoaPods can compile a file for only one architecture
   of a universal build. The wrappers make each file compile to nothing on
   x86_64. The upstream copies are excluded from compilation and only reached
   through the wrappers.
4. Skips the DNN-based features (DRED, OSCE). They're off by default in the
   current build and need large model files.

Upgrading libopus means bumping the tag and rerunning the script, so the
upgrade diff is the upstream source diff.

### config.h

`config.h` replaces the CMake configure step:

```c
#define OPUS_BUILD 1
#define USE_ALLOCA 1
#define HAVE_LRINT 1
#define HAVE_LRINTF 1
#define FLOAT_APPROX 1          /* only if the current CMake build enables it */

#if defined(__aarch64__)
/* Every arm64 Mac has NEON, so no runtime CPU detection is needed. */
#define OPUS_ARM_MAY_HAVE_NEON_INTR 1
#define OPUS_ARM_PRESUME_NEON_INTR 1
#define OPUS_ARM_PRESUME_AARCH64_NEON_INTR 1
#endif
```

On x86_64 this uses the generic C code paths. The SSE/AVX files need per-file
`-msse4.1` / `-mavx2` flags and runtime CPU detection, which neither build
system can express per file. Intel Macs lose some encoder performance. That's
an accepted trade-off on a shrinking platform, and it can be revisited if
anyone reports it. Before writing `config.h`, compare it against the
`config.h` that the current CMake build generates, so that both builds produce
the same configuration.

`OPUS_BUILD` matters for symbol visibility: with it, `opus_defines.h` marks
the public API `__attribute__((visibility("default")))`, so the API stays
exported even when the rest of the library is compiled with hidden visibility.

### Swift Package Manager

`COpus/Package.swift` mirrors `CSQLite`, including the dynamic product:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "COpus",
    platforms: [.macOS("10.14")],
    products: [
        // Dynamic, like CSQLite: keeps opus's symbols exported for
        // DynamicLibrary.process(). If linked statically, the linker would
        // dead-strip them because no Swift code calls them.
        .library(name: "COpus", type: .dynamic, targets: ["COpus"]),
    ],
    targets: [
        .target(
            name: "COpus",
            exclude: [/* upstream arch-specific files, reached via arch/ */],
            cSettings: [
                .define("HAVE_CONFIG_H"),
                .headerSearchPath("."),
                .headerSearchPath("celt"),
                .headerSearchPath("silk"),
                .headerSearchPath("silk/float"),
                .headerSearchPath("src"),
            ],
            linkerSettings: [.linkedLibrary("m")]
        ),
    ],
    cLanguageStandard: .gnu11
)
```

The plugin's `Package.swift` swaps the binary target for the package:

```swift
dependencies: [
    .package(path: "COpus"),
],
targets: [
    .target(
        name: "opus_codec_macos",
        dependencies: [.product(name: "COpus", package: "COpus")]
    ),
]
```

### CocoaPods

CocoaPods compiles the same files directly from the plugin's podspec:

```ruby
s.source_files = [
  'opus_codec_macos/Sources/opus_codec_macos/**/*.swift',
  'opus_codec_macos/COpus/Sources/COpus/{celt,silk,src,arch}/**/*.c',
]
s.exclude_files = [ # upstream arch-specific files, reached via arch/
]
s.preserve_paths = 'opus_codec_macos/COpus/Sources/COpus/**/*.{h,c}'
s.public_header_files = 'opus_codec_macos/COpus/Sources/COpus/include/*.h'
s.pod_target_xcconfig = {
  'DEFINES_MODULE' => 'YES',
  'GCC_PREPROCESSOR_DEFINITIONS' => 'HAVE_CONFIG_H=1',
  'HEADER_SEARCH_PATHS' => [
    '"${PODS_TARGET_SRCROOT}/opus_codec_macos/COpus/Sources/COpus"',
    '"${PODS_TARGET_SRCROOT}/opus_codec_macos/COpus/Sources/COpus/celt"',
    '"${PODS_TARGET_SRCROOT}/opus_codec_macos/COpus/Sources/COpus/silk"',
    '"${PODS_TARGET_SRCROOT}/opus_codec_macos/COpus/Sources/COpus/silk/float"',
    '"${PODS_TARGET_SRCROOT}/opus_codec_macos/COpus/Sources/COpus/src"',
  ].join(' '),
}
s.library = 'm'
```

The `s.vendored_frameworks` line is removed. Flutter's macOS Podfile template
uses `use_frameworks!`, so the plugin pod becomes a dynamic framework, and the
opus symbols are exported from it, which plays the same role as the dynamic
`COpus` product under SwiftPM.

### Dart side

No change. `DynamicLibrary.process()` already resolves symbols from every image
loaded into the process, which includes the `COpus` dynamic library (SwiftPM)
or the plugin framework (CocoaPods).

### Verification

The current CI uses path dependencies, so it can't catch packaging issues. The
checks below must run against a **published-like** copy of the package: the
archive produced by `flutter pub publish --dry-run`, or a pre-release version,
referenced through `dependency_overrides`.

1. `flutter pub publish --dry-run` in `opus_flutter_macos` lists no
   `.xcframework` and no symlinks.
2. The example builds and runs with SwiftPM and with CocoaPods
   (`flutter config --enable-swift-package-manager` /
   `--no-enable-swift-package-manager`), on the oldest (3.27.0) and latest
   supported Flutter versions.
3. A **release** build (`flutter build macos --release`) still encodes and
   decodes. Release builds dead-strip, so this is where missing symbols show
   up. Also check with `nm -gU` on the built `COpus` binary (or the plugin
   framework) that the `opus_*` functions opus_dart binds are exported.
4. `codesign -v --deep --strict` on the built `.app` passes.
5. Both arm64 and x86_64 slices build (`lipo -archs` on the binary).
6. The opus_dart unit tests pass against the new build. Encoding output may
   differ slightly on x86_64 because it no longer uses SIMD, so tests should
   compare decoded audio within a tolerance rather than byte-for-byte.

Add a CI job that builds the example from the dry-run archive, so a regression
in packaging shows up before publishing.

### Risks

- **Static linkage.** Apps whose Podfile uses
  `use_frameworks! :linkage => :static` (or no `use_frameworks!`) link the
  plugin statically, and dead stripping can drop the opus symbols in release
  builds. Document this. If it shows up in practice, force-keep the symbols
  with `-Wl,-u,_opus_…` linker flags for the functions opus_dart binds.
- **Local package path.** Flutter references plugins through a symlink in
  `macos/Flutter/ephemeral/Packages/.packages/`. `.package(path: "COpus")` is
  resolved relative to the plugin's real directory, which should work, but
  this needs testing first. If it fails, move `COpus` into its own git
  repository, exactly like `CSQLite`, and depend on it by pinned revision.
- **Build time.** Every clean app build compiles libopus (around 200 files,
  typically well under a minute on a modern Mac).
- **Package size.** The sources add a few MB to the pub archive, versus the
  roughly 1 MB binary they replace.

### iOS

`opus_codec_ios` doesn't have the symlink problem, because iOS frameworks use
the flat layout. It can keep its prebuilt framework. Once this works on macOS,
`COpus` can serve both platforms (a `darwin/` directory shared by both
packages), which removes the second build script and keeps the libopus
configuration identical across Apple platforms.

## Later: build hooks

`sqlite3_flutter_libs` is now end-of-life. `package:sqlite3` 3.x replaced all
of its per-platform build scripts with a Dart build hook (`hook/build.dart`)
that either downloads checksum-verified prebuilt libraries from GitHub
releases, or compiles SQLite from source using `native_toolchain_c`, for every
platform at once.

The same model would fit opus well: one `hook/build.dart` in `opus_codec_dart`
could replace the Android, iOS, macOS, Linux and Windows packages. It isn't
proposed now because hooks require Dart 3.10 (Flutter 3.38), while these
packages support Flutter 3.27 and later. The vendored sources and `config.h`
from this proposal carry over directly, because `native_toolchain_c` would
compile the same files with the same defines. This is worth revisiting when
the minimum Flutter version is raised.

## Rejected options

- **Shipping the xcframework as a zip.** It keeps the symlinks, but CocoaPods
  can't vendor a zip, so the podspec would have to unzip it as a side effect of
  `pod install`. It also keeps a binary in the repository.
- **Static library xcframework.** Avoids bundles, but the linker only pulls in
  object files that something references. Nothing in Swift calls opus, so the
  symbols `DynamicLibrary.process()` needs would be dropped unless force-loaded
  in every integration path.
- **Downloading the framework at build time.** Adds a network dependency to
  every `pod install` and SwiftPM resolution, and breaks offline and sandboxed
  builds. The hooks approach above does this properly, with checksums and a
  configurable mirror, once it becomes available.
- **Keeping the flat layout.** Current Xcode rejects it.
