// Compiles the vendored libopus (native/) and the shim into the opus_codec
// code asset. Runs for every build that depends on opus_codec_dart. Builds
// that do not request code assets, such as web, return before reading any
// native configuration.
import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Must match the `assetId` of the declarations in
/// lib/src/native/opus_bindings.dart.
const _assetName = 'src/native/opus_bindings.dart';

/// Targets with a tested configuration. Anything else fails before compiling.
final _supportedTargets = <OS, Set<Architecture>>{
  OS.macOS: {Architecture.arm64, Architecture.x64},
  OS.iOS: {Architecture.arm64, Architecture.x64},
  OS.android: {Architecture.arm, Architecture.arm64, Architecture.x64},
  OS.linux: {Architecture.x64, Architecture.arm64},
  OS.windows: {Architecture.x64},
};

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final code = input.config.code;
    final target = code.targetOS;
    final arch = code.targetArchitecture;
    if (!(_supportedTargets[target]?.contains(arch) ?? false)) {
      throw UnsupportedError(
        'opus_codec_dart has no libopus build for $target/$arch. '
        'See the support matrix in the package README.',
      );
    }

    final manifest = _readJson(input, 'native/libopus.json');
    final sources = _readJson(input, 'native/sources.json');
    final policy = manifest['feature_policy'] as Map<String, dynamic>;
    _checkFeaturePolicy(policy);

    final isWindows = target == OS.windows;
    final isElf = target == OS.linux || target == OS.android;

    final groups = sources['groups'] as Map<String, dynamic>;
    final files = [
      for (final group in groups.values)
        ...(group as List<dynamic>).cast<String>(),
    ];

    // native_toolchain_c before 0.19.3 runs cl.exe through cmd.exe, which
    // caps a command at 8191 characters; the absolute source paths alone
    // exceed that. cl reads them from a response file instead. 0.19.2 is what
    // Flutter 3.38 to 3.44 resolve, because they pin meta below 1.19.
    final sourceUris = [for (final f in files) input.packageRoot.resolve(f)];
    final responseFile = input.outputDirectory.resolve('sources.rsp');
    if (isWindows) {
      File.fromUri(responseFile).writeAsStringSync(
        [for (final uri in sourceUris) '"${uri.toFilePath()}"'].join('\n'),
      );
    }

    final library = CLibrary(
      name: 'opus_codec',
      assetName: _assetName,
      sources: isWindows ? const [] : files,
      includes: (sources['include_dirs'] as List<dynamic>).cast<String>(),
      defines: {
        'OPUS_BUILD': null,
        // Upstream sources include config.h (PACKAGE_VERSION) only when this
        // is set; without it the version string reads "libopus unknown".
        'HAVE_CONFIG_H': null,
        // C99 math.h on every supported target; selects the fast float-to-int
        // path in celt/float_cast.h, as CMake does after detecting them.
        'HAVE_LRINT': null,
        'HAVE_LRINTF': null,
        'DISABLE_DEBUG_FLOAT': null,
        if (policy['hardening'] == true) 'ENABLE_HARDENING': null,
        if (policy['float_api'] != true) 'DISABLE_FLOAT_API': null,
        // DLL_EXPORT makes OPUS_EXPORT mark symbols for export on Windows.
        if (isWindows) 'DLL_EXPORT': null,
        // MSVC has no variable-length arrays; alloca is the closest match.
        (isWindows ? 'USE_ALLOCA' : 'VAR_ARRAYS'): null,
      },
      flags: [
        // Only OPUS_EXPORT functions and the shim are visible, as on the
        // CMake shared build. Windows exports through __declspec instead.
        if (!isWindows) '-fvisibility=hidden',
        // ELF only: keep internal calls inside this library even when another
        // libopus with the same symbols is already loaded in the process.
        if (isElf) '-Wl,-Bsymbolic',
        // cl applies options to every source wherever they appear.
        if (isWindows) '@${responseFile.toFilePath()}',
      ],
      // ELF only: exp, log, cos and friends live in libm, which the linker
      // does not add by itself. Apple's libSystem and the MSVC CRT have them.
      libraries: [if (isElf) 'm'],
    );
    // CLibrary routes to a link hook and links statically when linking is
    // enabled (Flutter 3.47+ release builds). There is no hook/link.dart, so
    // always bundle a dynamic library.
    await library.build(
      input: input,
      output: output,
      routing: const [ToAppBundle()],
      linkModePreference: LinkModePreference.dynamic,
    );

    // Sources passed through the response file are not tracked by CBuilder.
    if (isWindows) output.dependencies.addAll(sourceUris);

    // Inputs the compiler does not see: the build still depends on them.
    for (final relative in [
      'native/libopus.json',
      'native/sources.json',
      'native/checksums.sha256',
    ]) {
      output.dependencies.add(input.packageRoot.resolve(relative));
    }
  });
}

Map<String, dynamic> _readJson(BuildInput input, String relative) {
  final file = File.fromUri(input.packageRoot.resolve(relative));
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// The hook compiles the float, generic-C baseline only. Enabling any of
/// these needs its own source groups and tests first.
void _checkFeaturePolicy(Map<String, dynamic> policy) {
  for (final unsupported in ['fixed_point', 'custom_modes', 'dnn']) {
    if (policy[unsupported] != false) {
      throw UnsupportedError(
        'native/libopus.json enables "$unsupported", which the build hook '
        'does not compile yet.',
      );
    }
  }
}
