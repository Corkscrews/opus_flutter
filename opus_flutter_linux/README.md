# opus_flutter_linux

The Linux implementation of [`opus_flutter`](https://pub.dev/packages/opus_flutter).

## Usage

This package is [endorsed](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin), so it is automatically included when you depend on `opus_flutter` in your Flutter application. No additional setup is required.

## Prerequisites

Unlike other platforms where opus is bundled with the plugin, the Linux implementation loads opus from the system. You must have `libopus` installed:

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

## How opus is loaded

The plugin calls `DynamicLibrary.open('libopus.so.0')` to load the system-installed opus library at runtime. If opus is not installed, a `DynamicLibrary` exception will be thrown.
