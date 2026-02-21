#!/usr/bin/env bash
#
# common.sh
#
# Shared colours, log helpers, and package lists used by every script
# in this folder.  Source this file; do not execute it directly.
#
# Usage:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()      { echo -e "${GREEN}[ OK ]${NC}  $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC}  $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[FAIL]${NC}  $1"; }
log_header()  { echo -e "\n${BOLD}$1${NC}"; }

# ---------------------------------------------------------------------------
# Package lists
# ---------------------------------------------------------------------------

FLUTTER_PACKAGES=(
  "opus_flutter_platform_interface"
  "opus_flutter_android"
  "opus_flutter_ios"
  "opus_flutter_linux"
  "opus_flutter_macos"
  "opus_flutter_windows"
  "opus_flutter"
)

DART_PACKAGE="opus_dart"
