import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffipackage;
import 'opus_dart_misc.dart' show ApiObject;

// coverage:ignore-start
ApiObject createApiObject(Object lib) {
  final library = lib as DynamicLibrary;
  return ApiObject(library, ffipackage.malloc);
}
// coverage:ignore-end
