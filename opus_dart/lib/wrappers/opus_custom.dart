// WARNING! Trying to use opus_custom will FAIL if opus_custom support
// was not enabled during library building!
//
// Contains methods and structs from the opus_custom group of opus_custom.h.
// SHOULD be imported as opus_custom.
//
// Vendored from https://github.com/EPNW/opus_dart
// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names

import '../src/proxy_ffi.dart' as ffi;

final class OpusCustomEncoder extends ffi.Opaque {}

final class OpusCustomDecoder extends ffi.Opaque {}

final class OpusCustomMode extends ffi.Opaque {}
