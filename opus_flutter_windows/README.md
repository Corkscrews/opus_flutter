# opus_codec_windows

The Windows implementation of [`opus_codec`][1].

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

If you wish to use the Windows package only, you can add `opus_codec_windows` as a
dependency:

```yaml
...
dependencies:
  ...
  opus_codec_windows: ^3.0.0
  ...
```

## How opus is contained in this package
Until Flutters Windows build system is more mature, we are follwing the recommendation from [Define distribution system for native libraries in Pub and/or Flutter](https://github.com/dart-lang/sdk/issues/36712).
This means, that prebuild opus libraries are contained in this package for x86 and x86_64 architectures. They are on runtime copied to a temporary directory using [path_provider](https://pub.dev/packages/path_provider) and then loaded from there. The contained binaries were build using docker with [`Dockerfile`][2].


[1]: ../opus_flutter
[2]: ./Dockerfile