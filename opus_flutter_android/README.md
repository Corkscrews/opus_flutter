# opus_codec_android

The Android implementation of [`opus_codec`][1].

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

If you wish to use the Android package only, you can add `opus_codec_android` as a
dependency:

```yaml
...
dependencies:
  ...
  opus_codec_android: ^3.0.0
  ...
```

## How opus is included

Opus is built from source at compile time using CMake's `FetchContent` module, which downloads a pinned release tag from the official repository. The build commands are in [`CMakeLists.txt`][2].

[1]: ../opus_flutter
[2]: ./android/src/main/CMakeLists.txt