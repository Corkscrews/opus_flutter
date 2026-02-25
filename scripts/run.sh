#!/usr/bin/env bash
#
# run.sh
#
# Runs the example app on a given target platform.
#
# Usage:
#   ./scripts/run.sh <platform>
#
# Platforms: android | ios | linux | macos | windows | web
#
# When no platform is given the script lists the platforms available on
# the current host.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

EXAMPLE_DIR="$ROOT_DIR/opus_flutter/example"

# ---------------------------------------------------------------------------
# Host → available targets
# ---------------------------------------------------------------------------
host_os="$(uname -s)"

available_platforms() {
  local platforms=()
  case "$host_os" in
    Darwin)  platforms=(android ios macos web) ;;
    Linux)   platforms=(android linux web) ;;
    MINGW*|MSYS*|CYGWIN*) platforms=(android windows web) ;;
    *)       platforms=(web) ;;
  esac
  echo "${platforms[@]}"
}

usage() {
  log_header "Usage: $0 <platform>"
  echo ""
  log_info "Available platforms on this host ($(uname -s)):"
  for p in $(available_platforms); do
    echo "  • $p"
  done
  exit 1
}

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  usage
fi

PLATFORM="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"

valid=false
for p in $(available_platforms); do
  [[ "$p" == "$PLATFORM" ]] && valid=true
done

if ! $valid; then
  log_error "Platform '$PLATFORM' is not supported on $host_os."
  echo ""
  log_info "Available platforms:"
  for p in $(available_platforms); do
    echo "  • $p"
  done
  exit 1
fi

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
log_header "Running example app on ${PLATFORM}"

cd "$EXAMPLE_DIR"
flutter pub get

case "$PLATFORM" in
  web)
    log_info "Starting web-server (use the URL printed below) …"
    flutter run -d web-server "${@:2}"
    ;;
  *)
    flutter run -d "$PLATFORM" "${@:2}"
    ;;
esac
