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

The opus library is built from source using CMake and packaged as an XCFramework containing a universal binary (arm64 + x86_64). The build commands can be found in [`build_xcframework.sh`][2]. The resulting `opus.xcframework` is vendored directly in this package and linked into your app at build time via CocoaPods.

[1]: ../opus_flutter
[2]: ./macos/build_xcframework.sh
