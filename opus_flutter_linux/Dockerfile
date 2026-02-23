FROM ubuntu:20.04

RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        cmake \
        git \
        gcc \
        g++ \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 --branch v1.5.2 https://github.com/xiph/opus.git opus-source

RUN mkdir -p out \
    && cmake -S opus-source -B build-x86_64 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="-O3 -fPIC" \
        -DBUILD_SHARED_LIBS=ON \
        -DOPUS_STACK_PROTECTOR=OFF \
        -DOPUS_BUILD_PROGRAMS=OFF \
        -DOPUS_DISABLE_INTRINSICS=ON \
        -DBUILD_TESTING=OFF \
    && cmake --build build-x86_64 --parallel \
    && cp build-x86_64/libopus.so.0.* out/libopus_x86_64.so

RUN cmake -S opus-source -B build-aarch64 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="-O3 -fPIC" \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
        -DBUILD_SHARED_LIBS=ON \
        -DOPUS_STACK_PROTECTOR=OFF \
        -DOPUS_BUILD_PROGRAMS=OFF \
        -DOPUS_DISABLE_INTRINSICS=ON \
        -DBUILD_TESTING=OFF \
    && cmake --build build-aarch64 --parallel \
    && cp build-aarch64/libopus.so.0.* out/libopus_aarch64.so

WORKDIR /build/out
