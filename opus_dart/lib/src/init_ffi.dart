import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffipackage;
import 'opus_dart_misc.dart' show ApiObject;

ApiObject createApiObject(Object lib) {
  final library = lib as DynamicLibrary;
  return new ApiObject(library as dynamic, ffipackage.malloc as dynamic);
}
