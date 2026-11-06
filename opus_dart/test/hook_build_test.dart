// Runs hook/build.dart against the host toolchain. Release builds in Flutter
// 3.47+ enable linking; with no hook/link.dart the library must still go to
// the app bundle as a dynamic library.
@TestOn('vm')
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as build_hook;

void main() {
  for (final linkingEnabled in [false, true]) {
    test(
      'bundles a dynamic library (linkingEnabled: $linkingEnabled)',
      () async {
        await testCodeBuildHook(
          mainMethod: build_hook.main,
          linkingEnabled: linkingEnabled,
          check: (input, output) {
            expect(output.assets.encodedAssetsForLinking, isEmpty);
            final asset = output.assets.code.single;
            expect(
              asset.id,
              'package:opus_codec_dart/src/native/opus_bindings.dart',
            );
            expect(asset.linkMode, isA<DynamicLoadingBundled>());
          },
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }

  // libopus calls exp, log, cos and friends. On ELF targets they live in
  // libm, which the linker does not add by itself; without it dlopen fails
  // on Android with `cannot locate symbol "exp"`.
  final readelf = _findReadelf();
  final elfTargets = [
    for (final arch in [Architecture.arm, Architecture.arm64, Architecture.x64])
      (OS.android, arch),
    if (OS.current == OS.linux) (OS.linux, Architecture.current),
  ];
  for (final (os, arch) in elfTargets) {
    test(
      'links libm on $os/$arch',
      () async {
        await testCodeBuildHook(
          mainMethod: build_hook.main,
          targetOS: os,
          targetArchitecture: arch,
          check: (input, output) {
            final file = output.assets.code.single.file!.toFilePath();
            final result = Process.runSync(readelf!, [
              '-d',
              '--dyn-syms',
              file,
            ]);
            expect(result.exitCode, 0, reason: '${result.stderr}');
            final elf = result.stdout as String;
            final needsLibm = RegExp(r'\(NEEDED\).*\[libm\.so').hasMatch(elf);
            final undefinedMath = RegExp(r' UND (\w+)')
                .allMatches(elf)
                .map((m) => m[1]!)
                .where(_mathSymbol.hasMatch)
                .toList();
            expect(undefinedMath, isNotEmpty, reason: 'readelf output:\n$elf');
            expect(
              needsLibm,
              isTrue,
              reason: '$file uses $undefinedMath but does not need libm',
            );
          },
        );
      },
      skip: readelf == null ? 'no llvm-readelf (Android NDK) found' : false,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}

final _mathSymbol = RegExp(
  r'^(a?(sin|cos|tan)h?|atan2|exp(2|m1)?|log(2|10|1p)?|pow|sqrt|cbrt|floor|'
  r'ceil|fmod|hypot|l?l?(rint|round)|trunc)[fl]?$',
);

/// The NDK's llvm-readelf, or the host's readelf on Linux.
String? _findReadelf() {
  final env = Platform.environment;
  final home = env['HOME'] ?? '';
  final ndkRoots = <Directory>[
    for (final name in [
      'ANDROID_NDK_HOME',
      'ANDROID_NDK_LATEST_HOME',
      'ANDROID_NDK_ROOT',
      'ANDROID_NDK',
    ])
      if (env[name] != null) Directory(env[name]!),
    for (final sdk in [
      env['ANDROID_HOME'],
      env['ANDROID_SDK_ROOT'],
      '$home/Library/Android/sdk',
      '$home/Android/Sdk',
    ])
      if (sdk != null && Directory('$sdk/ndk').existsSync())
        ...Directory('$sdk/ndk').listSync().whereType<Directory>(),
  ];
  for (final ndk in ndkRoots) {
    final prebuilt = Directory('${ndk.path}/toolchains/llvm/prebuilt');
    if (!prebuilt.existsSync()) continue;
    for (final host in prebuilt.listSync().whereType<Directory>()) {
      for (final name in ['llvm-readelf', 'llvm-readelf.exe']) {
        final tool = File('${host.path}/bin/$name');
        if (tool.existsSync()) return tool.path;
      }
    }
  }
  return null;
}
