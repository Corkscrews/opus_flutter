# Builds libopus.js/libopus.wasm from the same vendored libopus and shim that
# opus_codec_dart's build hook compiles for native platforms.
#
# Build context is the repository root:
#   ./build_wasm.sh
FROM emscripten/emsdk

WORKDIR /build

COPY opus_dart/native native

# Include paths and sources come from the manifest the native hook reads, so
# web and native always compile the same files.
RUN python3 -c "import json; d = json.load(open('native/sources.json')); \
print(' '.join(['-I' + p for p in d['include_dirs']] + \
[f for g in d['groups'].values() for f in g]))" > sources.args

# Defines mirror hook/build.dart (non-Windows branch). opus_codec_encoder_ctl_int
# is the fixed-signature CTL shim; the variadic opus_encoder_ctl is not exported.
RUN mkdir -p out && emcc -O3 \
      -DOPUS_BUILD -DHAVE_CONFIG_H -DHAVE_LRINT -DHAVE_LRINTF \
      -DDISABLE_DEBUG_FLOAT -DENABLE_HARDENING -DVAR_ARRAYS \
      $(cat sources.args) \
      -s MODULARIZE=1 \
      -s EXPORT_NAME=libopus \
      -s ALLOW_MEMORY_GROWTH=1 \
      -s EXPORTED_RUNTIME_METHODS='["HEAPU8"]' \
      -s EXPORTED_FUNCTIONS='[ \
        "_malloc", "_free", \
        "_opus_get_version_string", "_opus_strerror", \
        "_opus_encoder_get_size", "_opus_encoder_create", "_opus_encoder_init", \
        "_opus_encode", "_opus_encode_float", "_opus_encoder_destroy", \
        "_opus_codec_encoder_ctl_int", \
        "_opus_decoder_get_size", "_opus_decoder_create", "_opus_decoder_init", \
        "_opus_decode", "_opus_decode_float", "_opus_decoder_destroy", \
        "_opus_packet_parse", "_opus_packet_get_bandwidth", \
        "_opus_packet_get_samples_per_frame", "_opus_packet_get_nb_channels", \
        "_opus_packet_get_nb_frames", "_opus_packet_get_nb_samples", \
        "_opus_decoder_get_nb_samples", "_opus_pcm_soft_clip" \
      ]' \
      -o out/libopus.js

WORKDIR /build/out
