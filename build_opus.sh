#!/bin/bash
#
# Builds pre-compiled opus libraries for all platforms that need them.
#
# Platforms:
#   web      – WASM + JS glue via Docker (Emscripten)
#   windows  – DLLs (x86, x64) via Docker (MinGW cross-compile)
#   linux    – Shared libraries (x86_64, aarch64) via Docker
#   ios      – XCFramework via native Xcode toolchain
#   macos    – XCFramework via native Xcode toolchain
#
# Android builds from source at Gradle time (CMake FetchContent).
#
# Usage:
#   ./build_opus.sh              # build all platforms
#   ./build_opus.sh web          # build web only
#   ./build_opus.sh web windows  # build web and windows
#   ./build_opus.sh ios macos    # build ios and macos
#
# Requirements:
#   web/windows/linux : Docker
#   ios/macos         : Xcode CLI tools, CMake, Git

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPUS_VERSION="v1.5.2"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log()   { echo -e "${CYAN}[opus]${RESET} $*"; }
ok()    { echo -e "${GREEN}[opus]${RESET} $*"; }
err()   { echo -e "${RED}[opus]${RESET} $*" >&2; }

require_docker() {
  command -v docker >/dev/null 2>&1 || {
    err "Docker is required for $1 builds but was not found in PATH."
    exit 1
  }
}

# --------------------------------------------------------------------------- #
# Web
# --------------------------------------------------------------------------- #

build_web() {
  log "Building opus for ${BOLD}web${RESET} (WASM + JS via Emscripten)..."
  require_docker "web"

  local plugin_dir="$SCRIPT_DIR/opus_flutter_web"
  local assets_dir="$plugin_dir/assets"
  local image_tag="opus-flutter-web-builder"

  docker build -t "$image_tag" -f "$plugin_dir/Dockerfile" "$plugin_dir"

  local container_id
  container_id=$(docker create "$image_tag")

  mkdir -p "$assets_dir"
  docker cp "$container_id:/build/out/libopus.js"   "$assets_dir/libopus.js"
  docker cp "$container_id:/build/out/libopus.wasm"  "$assets_dir/libopus.wasm"
  docker rm "$container_id" > /dev/null

  local js_size wasm_size
  js_size=$(wc -c < "$assets_dir/libopus.js" | tr -d ' ')
  wasm_size=$(wc -c < "$assets_dir/libopus.wasm" | tr -d ' ')
  ok "Web build complete:"
  ok "  $assets_dir/libopus.js   ($js_size bytes)"
  ok "  $assets_dir/libopus.wasm ($wasm_size bytes)"
}

# --------------------------------------------------------------------------- #
# Windows
# --------------------------------------------------------------------------- #

build_windows() {
  log "Building opus for ${BOLD}windows${RESET} (x86 + x64 DLLs via MinGW)..."
  require_docker "windows"

  local plugin_dir="$SCRIPT_DIR/opus_flutter_windows"
  local assets_dir="$plugin_dir/assets"
  local image_tag="opus-flutter-windows-builder"

  docker build -t "$image_tag" -f "$plugin_dir/Dockerfile" "$plugin_dir"

  local container_id
  container_id=$(docker create "$image_tag")

  mkdir -p "$assets_dir"
  docker cp "$container_id:/app/libopus_x64.dll.blob"  "$assets_dir/libopus_x64.dll.blob"
  docker cp "$container_id:/app/libopus_x86.dll.blob"  "$assets_dir/libopus_x86.dll.blob"
  docker rm "$container_id" > /dev/null

  local x64_size x86_size
  x64_size=$(wc -c < "$assets_dir/libopus_x64.dll.blob" | tr -d ' ')
  x86_size=$(wc -c < "$assets_dir/libopus_x86.dll.blob" | tr -d ' ')
  ok "Windows build complete:"
  ok "  $assets_dir/libopus_x64.dll.blob ($x64_size bytes)"
  ok "  $assets_dir/libopus_x86.dll.blob ($x86_size bytes)"
}

# --------------------------------------------------------------------------- #
# Linux
# --------------------------------------------------------------------------- #

build_linux() {
  log "Building opus for ${BOLD}linux${RESET} (x86_64 + aarch64 shared libraries)..."
  require_docker "linux"

  local plugin_dir="$SCRIPT_DIR/opus_flutter_linux"
  local assets_dir="$plugin_dir/assets"
  local image_tag="opus-flutter-linux-builder"

  docker build -t "$image_tag" -f "$plugin_dir/Dockerfile" "$plugin_dir"

  local container_id
  container_id=$(docker create "$image_tag")

  mkdir -p "$assets_dir"
  docker cp "$container_id:/build/out/libopus_x86_64.so"  "$assets_dir/libopus_x86_64.so.blob"
  docker cp "$container_id:/build/out/libopus_aarch64.so"  "$assets_dir/libopus_aarch64.so.blob"
  docker rm "$container_id" > /dev/null

  local x86_64_size aarch64_size
  x86_64_size=$(wc -c < "$assets_dir/libopus_x86_64.so.blob" | tr -d ' ')
  aarch64_size=$(wc -c < "$assets_dir/libopus_aarch64.so.blob" | tr -d ' ')
  ok "Linux build complete:"
  ok "  $assets_dir/libopus_x86_64.so.blob  ($x86_64_size bytes)"
  ok "  $assets_dir/libopus_aarch64.so.blob ($aarch64_size bytes)"
}

# --------------------------------------------------------------------------- #
# iOS
# --------------------------------------------------------------------------- #

build_ios() {
  log "Building opus for ${BOLD}iOS${RESET} (XCFramework)..."

  local build_script="$SCRIPT_DIR/opus_flutter_ios/ios/build_xcframework.sh"
  if [ ! -f "$build_script" ]; then
    err "Missing build script: $build_script"
    exit 1
  fi

  chmod +x "$build_script"
  "$build_script"
  ok "iOS build complete."
}

# --------------------------------------------------------------------------- #
# macOS
# --------------------------------------------------------------------------- #

build_macos() {
  log "Building opus for ${BOLD}macOS${RESET} (XCFramework)..."

  local build_script="$SCRIPT_DIR/opus_flutter_macos/macos/build_xcframework.sh"
  if [ ! -f "$build_script" ]; then
    err "Missing build script: $build_script"
    exit 1
  fi

  chmod +x "$build_script"
  "$build_script"
  ok "macOS build complete."
}

# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #

ALL_PLATFORMS=(web windows linux ios macos)

print_usage() {
  echo "Usage: $0 [platform ...]"
  echo ""
  echo "Platforms: ${ALL_PLATFORMS[*]}"
  echo ""
  echo "If no platforms are specified, all are built."
  echo ""
  echo "Examples:"
  echo "  $0              # build all"
  echo "  $0 web          # build web only"
  echo "  $0 web windows  # build web and windows"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_usage
  exit 0
fi

targets=("${@:-}")
if [ ${#targets[@]} -eq 0 ] || [ -z "${targets[0]}" ]; then
  targets=("${ALL_PLATFORMS[@]}")
fi

echo ""
log "opus ${BOLD}${OPUS_VERSION}${RESET} – building for: ${BOLD}${targets[*]}${RESET}"
echo ""

for target in "${targets[@]}"; do
  case "$target" in
    web)     build_web     ;;
    windows) build_windows ;;
    linux)   build_linux   ;;
    ios)     build_ios     ;;
    macos)   build_macos   ;;
    *)
      err "Unknown platform: $target"
      print_usage
      exit 1
      ;;
  esac
  echo ""
done

ok "${BOLD}All done!${RESET}"
