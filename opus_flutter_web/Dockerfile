FROM emscripten/emsdk

WORKDIR /build

RUN git clone --depth 1 --branch v1.5.2 https://github.com/xiph/opus.git opus-source

RUN emcmake cmake -S opus-source -B opus-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_FLAGS="-O3 -fPIC" \
      -DBUILD_SHARED_LIBS=OFF \
      -DOPUS_STACK_PROTECTOR=OFF \
      -DOPUS_BUILD_PROGRAMS=OFF \
      -DOPUS_DISABLE_INTRINSICS=ON \
      -DBUILD_TESTING=OFF \
    && cmake --build opus-build --parallel

RUN mkdir -p out && emcc -O3 \
      -s MODULARIZE=1 \
      -s EXPORT_NAME=libopus \
      -s ALLOW_MEMORY_GROWTH=1 \
      -s EXPORTED_RUNTIME_METHODS='["HEAPU8"]' \
      -s EXPORTED_FUNCTIONS='[ \
        "_malloc", "_free", \
        "_opus_get_version_string", "_opus_strerror", \
        "_opus_encoder_get_size", "_opus_encoder_create", "_opus_encoder_init", \
        "_opus_encode", "_opus_encode_float", "_opus_encoder_destroy", \
        "_opus_decoder_get_size", "_opus_decoder_create", "_opus_decoder_init", \
        "_opus_decode", "_opus_decode_float", "_opus_decoder_destroy", \
        "_opus_packet_parse", "_opus_packet_get_bandwidth", \
        "_opus_packet_get_samples_per_frame", "_opus_packet_get_nb_channels", \
        "_opus_packet_get_nb_frames", "_opus_packet_get_nb_samples", \
        "_opus_decoder_get_nb_samples", "_opus_pcm_soft_clip" \
      ]' \
      opus-build/libopus.a -o out/libopus.js

WORKDIR /build/out
