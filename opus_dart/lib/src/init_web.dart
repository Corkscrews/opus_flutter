// This file is only loaded on web via the conditional export in proxy_ffi.dart.
// The analyzer on native cannot fully resolve wasm_ffi types against dart:ffi
// types from the wrapper files, so we suppress the resulting false positives.
// ignore_for_file: type_argument_not_matching_bounds, argument_type_not_assignable

import 'package:wasm_ffi/ffi.dart';

import 'opus_dart_misc.dart' show ApiObject;

import '../wrappers/opus_custom.dart' as opus_custom;
import '../wrappers/opus_multistream.dart' as opus_multistream;
import '../wrappers/opus_projection.dart' as opus_projection;
import '../wrappers/opus_repacketizer.dart' as opus_repacketizer;
import '../wrappers/opus_encoder.dart' as opus_encoder;
import '../wrappers/opus_decoder.dart' as opus_decoder;

ApiObject createApiObject(Object lib) {
  final library = lib as DynamicLibrary;
  registerOpaqueType<opus_encoder.OpusEncoder>();
  registerOpaqueType<opus_decoder.OpusDecoder>();
  registerOpaqueType<opus_custom.OpusCustomEncoder>();
  registerOpaqueType<opus_custom.OpusCustomDecoder>();
  registerOpaqueType<opus_multistream.OpusMSEncoder>();
  registerOpaqueType<opus_multistream.OpusMSDecoder>();
  registerOpaqueType<opus_projection.OpusProjectionEncoder>();
  registerOpaqueType<opus_projection.OpusProjectionDecoder>();
  registerOpaqueType<opus_repacketizer.OpusRepacketizer>();
  registerOpaqueType<opus_repacketizer.OpusRepacketizer>();
  return ApiObject(library, library.allocator);
}
