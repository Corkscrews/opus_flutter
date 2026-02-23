# opus_codec_linux

The Linux implementation of [`opus_codec`](https://pub.dev/packages/opus_codec).

## Usage

This package is [endorsed](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin), so it is automatically included when you depend on `opus_codec` in your Flutter application. No additional setup is required.

## How opus is loaded

The plugin uses a two-tier loading strategy:

1. **Bundled library (preferred):** A prebuilt `libopus` shared object is shipped as a Flutter asset (`libopus_x86_64.so.blob` or `libopus_aarch64.so.blob`). On first use it is copied to the system temporary directory and opened with `DynamicLibrary.open`. The copied file is reused on subsequent calls.

2. **System fallback:** If the bundled library cannot be loaded (missing asset, unsupported architecture, corrupted file, etc.), the plugin falls back to `DynamicLibrary.open('libopus.so.0')`, which loads the system-installed version.

If neither option succeeds an `ArgumentError` is thrown with installation instructions.

### Supported architectures

| Architecture | Bundled asset |
|--------------|---------------|
| x86_64       | `libopus_x86_64.so.blob` |
| aarch64      | `libopus_aarch64.so.blob` |

### Installing the system library (fallback)

If the bundled binary does not work on your distribution you can install `libopus` from your package manager:

**Debian/Ubuntu:**
```bash
sudo apt install libopus0
```

**Fedora:**
```bash
sudo dnf install opus
```

**Arch Linux:**
```bash
sudo pacman -S opus
```
