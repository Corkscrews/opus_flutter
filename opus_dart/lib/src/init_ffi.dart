import 'package:ffi/ffi.dart' as ffipackage;

import 'native/api_adapter.dart';
import 'opus_dart_misc.dart' show ApiObject;

// coverage:ignore-start
/// Native backend: libopus comes from the code asset built by hook/build.dart,
/// so no library is passed in.
ApiObject createApiObject(Object? opusLib) {
  if (opusLib != null) {
    throw ArgumentError.value(
      opusLib,
      'opusLib',
      'libopus is bundled as a code asset on native platforms; '
          'call initOpus() without a library',
    );
  }
  return ApiObject.fromFunctions(
    libinfo: const NativeOpusLibInfo(),
    encoder: const NativeOpusEncoder(),
    decoder: const NativeOpusDecoder(),
    allocator: ffipackage.malloc,
  );
}
// coverage:ignore-end
