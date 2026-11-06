#!/bin/bash
#
# Builds the web backend (libopus.js + libopus.wasm) into
# opus_flutter_web/assets with Emscripten in Docker.
#
# Native platforms need no prebuilt library: opus_codec_dart's build hook
# compiles the same vendored sources (opus_dart/native) at app build time.
#
# Usage:
#   ./build_wasm.sh
#
# Requirements: Docker.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/opus_flutter_web/assets"
IMAGE_TAG="opus-flutter-web-builder"

command -v docker >/dev/null 2>&1 || {
  echo "Docker is required but was not found in PATH." >&2
  exit 1
}

python3 "$SCRIPT_DIR/scripts/vendor_libopus.py" --check

docker build -t "$IMAGE_TAG" -f "$SCRIPT_DIR/opus_flutter_web/Dockerfile" "$SCRIPT_DIR"

container_id=$(docker create "$IMAGE_TAG")
trap 'docker rm "$container_id" >/dev/null' EXIT

mkdir -p "$ASSETS_DIR"
docker cp "$container_id:/build/out/libopus.js" "$ASSETS_DIR/libopus.js"
docker cp "$container_id:/build/out/libopus.wasm" "$ASSETS_DIR/libopus.wasm"

echo "Web build complete:"
echo "  $ASSETS_DIR/libopus.js   ($(wc -c < "$ASSETS_DIR/libopus.js" | tr -d ' ') bytes)"
echo "  $ASSETS_DIR/libopus.wasm ($(wc -c < "$ASSETS_DIR/libopus.wasm" | tr -d ' ') bytes)"
