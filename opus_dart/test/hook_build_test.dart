// Runs hook/build.dart against the host toolchain. Release builds in Flutter
// 3.47+ enable linking; with no hook/link.dart the library must still go to
// the app bundle as a dynamic library.
@TestOn('vm')
library;

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
}
