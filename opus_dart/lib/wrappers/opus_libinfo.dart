/// Contains methods and structs from the opus_libinfo group of opus_defines.h.
/// SHOULD be imported as opus_libinfo.
///
/// Vendored from https://github.com/EPNW/opus_dart
// ignore_for_file: camel_case_types, non_constant_identifier_names, constant_identifier_names

library opus_libinfo;

import '../src/proxy_ffi.dart' as ffi;

typedef _opus_get_version_string_C = ffi.Pointer<ffi.Uint8> Function();
typedef _opus_get_version_string_Dart = ffi.Pointer<ffi.Uint8> Function();
typedef _opus_strerror_C = ffi.Pointer<ffi.Uint8> Function(
  ffi.Int32 error,
);
typedef _opus_strerror_Dart = ffi.Pointer<ffi.Uint8> Function(
  int error,
);

class FunctionsAndGlobals {
  FunctionsAndGlobals(ffi.DynamicLibrary _dynamicLibrary)
      : _opus_get_version_string = _dynamicLibrary.lookupFunction<
            _opus_get_version_string_C, _opus_get_version_string_Dart>(
          'opus_get_version_string',
        ),
        _opus_strerror = _dynamicLibrary
            .lookupFunction<_opus_strerror_C, _opus_strerror_Dart>(
          'opus_strerror',
        );

  ffi.Pointer<ffi.Uint8> opus_get_version_string() {
    return _opus_get_version_string();
  }

  final _opus_get_version_string_Dart _opus_get_version_string;

  ffi.Pointer<ffi.Uint8> opus_strerror(
    int error,
  ) {
    return _opus_strerror(error);
  }

  final _opus_strerror_Dart _opus_strerror;
}
