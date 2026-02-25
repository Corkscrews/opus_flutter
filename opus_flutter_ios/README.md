# opus_codec_ios

The iOS implementation of [`opus_codec`][1].

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

If you wish to use the iOS package only, you can add `opus_codec_ios` as a
dependency:

```yaml
...
dependencies:
  ...
  opus_codec_ios: ^3.0.1
  ...
```

## How opus is included

Opus is built from source using CMake and packaged as an XCFramework containing a universal binary (arm64 + x86_64 simulator). The build commands are in [`build_xcframework.sh`][2]. The resulting `opus.xcframework` is vendored in this package and linked at build time via CocoaPods.

[1]: ../opus_flutter
[2]: ./ios/build_xcframework.sh
