/*
 * Non-variadic wrappers for opus_encoder_ctl.
 *
 * Emscripten compiles variadic C functions with a different ABI: variadic
 * arguments are packed into a stack-allocated buffer rather than passed as
 * individual WASM parameters.  Dart's wasm_ffi lookupFunction binds to the
 * raw WASM export and has no knowledge of this indirection, so calling the
 * variadic export directly from Dart produces undefined behavior.
 *
 * These thin wrappers present a fixed-signature function that Dart can
 * safely call via lookupFunction on the web platform.
 */

#include "opus/opus.h"

int opus_encoder_ctl_int(OpusEncoder *st, int request, int value) {
    return opus_encoder_ctl(st, request, value);
}
