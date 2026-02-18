/// WARNING! Trying to use opus_custom will FAIL if opus_custom support
/// was not enabled during library building!
///
/// Contains methods and structs from the opus_custom group of opus_custom.h.
/// SHOULD be imported as opus_custom.
///
/// AUTOMATICALLY GENERATED FILE. DO NOT MODIFY.
// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names
// ignore_for_file: subtype_of_sealed_class

library opus_custom;

import '../src/proxy_ffi.dart' as ffi;

class OpusCustomEncoder extends ffi.Opaque {}

class OpusCustomDecoder extends ffi.Opaque {}

class OpusCustomMode extends ffi.Opaque {}
