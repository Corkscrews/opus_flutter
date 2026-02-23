#!/bin/bash
#
# Builds opus.xcframework by cloning libopus from GitHub at build time.
#
# The resulting xcframework contains:
#   - ios-arm64                      (physical devices)
#   - ios-arm64_x86_64-simulator     (Apple Silicon + Intel simulators)
#
# Requirements:
#   - Xcode command line tools (clang, xcodebuild, lipo, xcrun)
#   - CMake (brew install cmake)
#
# Usage:
#   cd opus_flutter_ios/ios
#   ./build_xcframework.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

OPUS_VERSION="v1.5.2"
FRAMEWORK_NAME="opus"
FRAMEWORK_VERSION="1.5.2"
FRAMEWORK_BUNDLE_ID="org.opus-codec.opus"
IOS_DEPLOYMENT_TARGET="13.0"

# --------------------------------------------------------------------------- #
# Preflight checks
# --------------------------------------------------------------------------- #

for cmd in git cmake xcrun xcodebuild lipo; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: '$cmd' is required but not found in PATH." >&2
    exit 1
  }
done

echo "============================================="
echo " Building opus.xcframework"
echo "============================================="
echo "  opus version   : $OPUS_VERSION"
echo "  Build directory: $BUILD_DIR"
echo "  iOS deployment : $IOS_DEPLOYMENT_TARGET"
echo ""

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

LIBOPUS_SRC="$BUILD_DIR/opus-source"
git clone --depth 1 --branch "$OPUS_VERSION" \
    https://github.com/xiph/opus.git "$LIBOPUS_SRC"
echo ""

# --------------------------------------------------------------------------- #
# Step 1 – Build static libraries with CMake for each (sdk, arch) pair
# --------------------------------------------------------------------------- #

build_static_lib() {
  local sdk="$1"   # iphoneos | iphonesimulator
  local arch="$2"  # arm64 | x86_64
  local build_dir="$BUILD_DIR/${sdk}-${arch}"
  local sdk_path
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"

  echo "--- Building libopus.a  sdk=$sdk  arch=$arch ---"

  cmake -S "$LIBOPUS_SRC" -B "$build_dir" \
    -G "Unix Makefiles" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_SYSROOT="$sdk_path" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
    -DCMAKE_INSTALL_PREFIX="$build_dir/install" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DBUILD_SHARED_LIBS=OFF \
    -DOPUS_STACK_PROTECTOR=OFF \
    -DOPUS_BUILD_PROGRAMS=OFF \
    -DBUILD_TESTING=OFF

  cmake --build "$build_dir" -- -j"$(sysctl -n hw.logicalcpu)"
  cmake --install "$build_dir"
  echo ""
}

build_static_lib iphoneos       arm64
build_static_lib iphonesimulator arm64
build_static_lib iphonesimulator x86_64

# --------------------------------------------------------------------------- #
# Step 2 – Wrap static libs into .framework bundles (as dynamic frameworks)
# --------------------------------------------------------------------------- #

create_framework() {
  local label="$1"  # device | simulator
  local sdk="$2"    # iphoneos | iphonesimulator
  shift 2
  # Remaining positional args: "arch:path_to_static_lib" …
  local arch_lib_pairs=("$@")

  local fw_dir="$BUILD_DIR/frameworks/$label/$FRAMEWORK_NAME.framework"
  mkdir -p "$fw_dir/Headers" "$fw_dir/Modules"

  # --- Public headers (identical across architectures) ---
  cp "$BUILD_DIR/iphoneos-arm64/install/include/opus/"*.h "$fw_dir/Headers/"

  # --- module.modulemap ---
  cat > "$fw_dir/Modules/module.modulemap" <<'MODULEMAP'
framework module opus {
  umbrella header "opus.h"
  export *

  module * { export * }
}
MODULEMAP

  # --- Info.plist ---
  cat > "$fw_dir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$FRAMEWORK_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$FRAMEWORK_BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$FRAMEWORK_NAME</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>$FRAMEWORK_VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>MinimumOSVersion</key>
  <string>$IOS_DEPLOYMENT_TARGET</string>
</dict>
</plist>
PLIST

  # --- Link static lib(s) → dynamic framework binary ---
  local sdk_path
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"

  local version_min_flag
  if [ "$sdk" = "iphoneos" ]; then
    version_min_flag="-miphoneos-version-min=$IOS_DEPLOYMENT_TARGET"
  else
    version_min_flag="-mios-simulator-version-min=$IOS_DEPLOYMENT_TARGET"
  fi

  local tmp_dylibs=()
  for pair in "${arch_lib_pairs[@]}"; do
    local arch="${pair%%:*}"
    local static_lib="${pair##*:}"
    local tmp_dylib="$BUILD_DIR/tmp_${label}_${arch}.dylib"

    xcrun clang -arch "$arch" \
      -isysroot "$sdk_path" \
      -dynamiclib \
      -install_name "@rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" \
      -Wl,-all_load "$static_lib" \
      "$version_min_flag" \
      -lm \
      -compatibility_version 1.0 \
      -current_version "$FRAMEWORK_VERSION" \
      -o "$tmp_dylib"

    tmp_dylibs+=("$tmp_dylib")
  done

  if [ ${#tmp_dylibs[@]} -eq 1 ]; then
    cp "${tmp_dylibs[0]}" "$fw_dir/$FRAMEWORK_NAME"
  else
    lipo -create "${tmp_dylibs[@]}" -output "$fw_dir/$FRAMEWORK_NAME"
  fi
  rm -f "${tmp_dylibs[@]}"

  echo "$fw_dir"
}

echo "============================================="
echo " Packaging frameworks"
echo "============================================="

device_fw=$(create_framework "device" "iphoneos" \
  "arm64:$BUILD_DIR/iphoneos-arm64/install/lib/libopus.a")

simulator_fw=$(create_framework "simulator" "iphonesimulator" \
  "arm64:$BUILD_DIR/iphonesimulator-arm64/install/lib/libopus.a" \
  "x86_64:$BUILD_DIR/iphonesimulator-x86_64/install/lib/libopus.a")

echo "  Device framework   : $device_fw"
echo "  Simulator framework: $simulator_fw"
echo ""

# --------------------------------------------------------------------------- #
# Step 3 – Assemble the XCFramework
# --------------------------------------------------------------------------- #

echo "============================================="
echo " Creating XCFramework"
echo "============================================="

rm -rf "$SCRIPT_DIR/$FRAMEWORK_NAME.xcframework"

xcodebuild -create-xcframework \
  -framework "$device_fw" \
  -framework "$simulator_fw" \
  -output "$SCRIPT_DIR/$FRAMEWORK_NAME.xcframework"

echo ""

# --------------------------------------------------------------------------- #
# Clean up
# --------------------------------------------------------------------------- #

rm -rf "$BUILD_DIR"

echo "============================================="
echo " Done!"
echo "============================================="
echo ""
echo "Output: $SCRIPT_DIR/$FRAMEWORK_NAME.xcframework"
echo ""
echo "Architectures:"
for fw in "$SCRIPT_DIR/$FRAMEWORK_NAME.xcframework/"*"/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"; do
  if [ -f "$fw" ]; then
    local_dir="$(basename "$(dirname "$(dirname "$fw")")")"
    echo "  $local_dir : $(lipo -archs "$fw")"
  fi
done
