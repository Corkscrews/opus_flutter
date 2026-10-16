# opus_codec_macos

The macOS implementation of [`opus_codec`][1].

## Usage

### Import the package

This package has been endorsed, meaning that you only need to add `opus_codec`
as a dependency in your `pubspec.yaml`. It will be automatically included in your app
when you depend on `package:opus_codec`.

This is what the above means to your `pubspec.yaml`:

```yaml
...
dependencies:
  ...
  opus_codec: ^3.0.0
  ...
```

If you wish to use the macOS package only, you can add `opus_codec_macos` as a
dependency:

```yaml
...
dependencies:
  ...
  opus_codec_macos: ^3.0.0
  ...
```

## How opus is contained in this package

The opus library is built from source using CMake and packaged as an XCFramework containing a universal binary (arm64 + x86_64). The build commands can be found in [`build_xcframework.sh`][2]. The resulting `macos/opus_codec_macos/opus.xcframework` is vendored inside the Swift package and linked into your app at build time via Swift Package Manager or CocoaPods.

## Known issue: macOS builds fail when installed from pub.dev

Recent Xcode versions only accept macOS frameworks in the versioned ("deep")
bundle layout:

```
opus.framework/
├── opus       -> Versions/Current/opus
├── Headers    -> Versions/Current/Headers
├── Modules    -> Versions/Current/Modules
├── Resources  -> Versions/Current/Resources
└── Versions/
    ├── A/     (binary, Headers, Modules, Resources/Info.plist)
    └── Current -> A
```

The flat iOS-style layout used up to 3.1.0 now fails with:

```
error: Framework .../opus.framework contains Info.plist, expected
Versions/Current/Resources/Info.plist since the platform does not use shallow bundles
```

The framework in this repository now uses the deep layout, which works when the
package comes from git or a path dependency. However, `pub publish` replaces
symlinks with copies of their targets, so the package on pub.dev arrives with
real directories where the symlinks should be. Xcode then fails to resolve
`Versions/Current` and code signing fails.

Until this is fixed, macOS apps should depend on the package from git:

```yaml
dependency_overrides:
  opus_codec_macos:
    git:
      url: https://github.com/Corkscrews/opus_flutter.git
      path: opus_flutter_macos
```

The proposed fix is described in [docs/macos-xcframework-distribution.md][3].

[1]: ../opus_flutter
[2]: ./macos/build_xcframework.sh
[3]: https://github.com/Corkscrews/opus_flutter/blob/master/docs/macos-xcframework-distribution.md
