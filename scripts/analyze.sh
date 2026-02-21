#!/usr/bin/env bash
#
# analyze.sh
#
# Runs `flutter analyze` / `dart analyze` for every package in the monorepo
# and reports a pass/fail summary.
#
# Usage:
#   ./scripts/analyze.sh
#
# Requirements:
#   - flutter (stable channel)
#   - dart (bundled with flutter)

set -uo pipefail

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
log_success() { echo -e "${GREEN}[PASS]${NC}  $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[FAIL]${NC}  $1"; }
log_header()  { echo -e "\n${BOLD}$1${NC}"; }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Packages analyzed with `flutter analyze`
FLUTTER_PACKAGES=(
  "opus_flutter_platform_interface"
  "opus_flutter_android"
  "opus_flutter_ios"
  "opus_flutter_linux"
  "opus_flutter_macos"
  "opus_flutter_windows"
  "opus_flutter"
)

# Package analyzed with `dart analyze` (pure Dart, no Flutter)
DART_PACKAGE="opus_dart"

# ---------------------------------------------------------------------------
# Tracking
# ---------------------------------------------------------------------------
failed_packages=()
passed_packages=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# run_flutter_analyze <package>
run_flutter_analyze() {
  local package="$1"
  local package_dir="$ROOT_DIR/$package"

  log_header "▸ $package"

  if [ ! -d "$package_dir" ]; then
    log_warning "Directory not found, skipping: $package_dir"
    return 0
  fi

  (
    cd "$package_dir"
    flutter pub get
    flutter analyze
  )
  local exit_code=$?

  if [ $exit_code -eq 0 ]; then
    log_success "$package"
    passed_packages+=("$package")
  else
    log_error "$package"
    failed_packages+=("$package")
  fi
}

# run_dart_analyze <package>
run_dart_analyze() {
  local package="$1"
  local package_dir="$ROOT_DIR/$package"

  log_header "▸ $package (dart)"

  if [ ! -d "$package_dir" ]; then
    log_warning "Directory not found, skipping: $package_dir"
    return 0
  fi

  (
    cd "$package_dir"
    dart pub get
    dart analyze
  )
  local exit_code=$?

  if [ $exit_code -eq 0 ]; then
    log_success "$package"
    passed_packages+=("$package")
  else
    log_error "$package"
    failed_packages+=("$package")
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo -e "${BOLD}Static analysis — $(date '+%Y-%m-%d %H:%M')${NC}"
echo "Root: $ROOT_DIR"

log_header "━━━ Running analysis ━━━"

for package in "${FLUTTER_PACKAGES[@]}"; do
  run_flutter_analyze "$package"
done

run_dart_analyze "$DART_PACKAGE"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo -e "${BOLD}Results${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"

if [ ${#passed_packages[@]} -gt 0 ]; then
  echo -e "${GREEN}Passed (${#passed_packages[@]}):${NC}"
  for pkg in "${passed_packages[@]}"; do
    echo -e "  ${GREEN}✓${NC}  $pkg"
  done
fi

if [ ${#failed_packages[@]} -gt 0 ]; then
  echo ""
  echo -e "${RED}Failed (${#failed_packages[@]}):${NC}"
  for pkg in "${failed_packages[@]}"; do
    echo -e "  ${RED}✗${NC}  $pkg"
  done
  echo ""
  exit 1
fi

echo ""
echo -e "${GREEN}${BOLD}All packages passed analysis!${NC}"
