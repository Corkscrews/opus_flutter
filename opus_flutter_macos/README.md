# opus_flutter_macos

The macOS implementation of [`opus_flutter`][1].

## Usage

### Import the package

This package has been endorsed, meaning that you only need to add `opus_flutter`
as a dependency in your `pubspec.yaml`. It will be automatically included in your app
when you depend on `package:opus_flutter`.

This is what the above means to your `pubspec.yaml`:

```yaml
...
dependencies:
  ...
  opus_flutter: ^3.0.0
  ...
```

If you wish to use the macOS package only, you can add `opus_flutter_macos` as a
dependency:

```yaml
...
dependencies:
  ...
  opus_flutter_macos: ^3.0.0
  ...
```

## How opus is contained in this package

The opus library is built from source using CMake and packaged as an XCFramework containing a universal binary (arm64 + x86_64). The build commands can be found in [`build_xcframework.sh`][2]. The resulting `opus.xcframework` is vendored directly in this package and linked into your app at build time via CocoaPods.

[1]: ../opus_flutter
[2]: ./macos/build_xcframework.sh
