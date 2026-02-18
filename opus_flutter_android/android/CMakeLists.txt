cmake_minimum_required(VERSION 3.18)
project(opus_flutter_android)

include(FetchContent)
FetchContent_Declare(
  opus
  URL https://github.com/xiph/opus/archive/refs/tags/v1.5.2.tar.gz
)

set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
set(OPUS_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(OPUS_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(OPUS_INSTALL_PKG_CONFIG_MODULE OFF CACHE BOOL "" FORCE)
set(OPUS_INSTALL_CMAKE_CONFIG_MODULE OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(opus)

# Ensure 16 KB ELF alignment for Android 15+ devices (safe no-op on NDK r28+)
target_link_options(opus PRIVATE "-Wl,-z,max-page-size=16384")
