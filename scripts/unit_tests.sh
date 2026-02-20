#!/usr/bin/env bash
#
# unit_tests.sh
#
# Runs all unit tests across every package in the monorepo and collects
# per-package lcov coverage reports.  When `lcov` is available on the PATH
# all individual reports are merged into a single coverage/lcov.info at the
# repository root.
#
# Usage:
#   ./scripts/unit_tests.sh
#
# Requirements:
#   - flutter (stable channel)
#   - dart (bundled with flutter)
#   - lcov (optional, for merging reports)  →  brew install lcov
#   - dart pub global activate coverage   (for opus_dart dart-only coverage)

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

# Packages tested with `flutter test --coverage`
FLUTTER_PACKAGES=(
  "opus_flutter_platform_interface"
  "opus_flutter_android"
  "opus_flutter_ios"
  "opus_flutter_linux"
  "opus_flutter_macos"
  "opus_flutter_windows"
  "opus_flutter"
)

# Package tested with `dart test` (pure Dart, no Flutter)
DART_PACKAGE="opus_dart"

# Where per-package lcov files and the merged report are written
COVERAGE_DIR="$ROOT_DIR/coverage"
MERGED_LCOV="$COVERAGE_DIR/lcov.info"

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
failed_packages=()
passed_packages=()

rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# copy_lcov <package> <source_lcov>
# Normalises SF: paths so they are relative to the repo root.
#   Absolute:  SF:/full/repo/path/<package>/lib/… → SF:<package>/lib/…
#   Relative:  SF:lib/…                          → SF:<package>/lib/…
copy_lcov() {
  local package="$1"
  local source="$2"
  if [ -f "$source" ]; then
    sed \
      -e "s|^SF:${ROOT_DIR}/${package}/|SF:${package}/|" \
      -e "s|^SF:lib/|SF:${package}/lib/|" \
      "$source" > "$COVERAGE_DIR/${package}.lcov.info"
    log_info "Coverage saved → coverage/${package}.lcov.info"
  else
    log_warning "No lcov.info generated for $package"
  fi
}

# run_flutter_tests <package>
run_flutter_tests() {
  local package="$1"
  local package_dir="$ROOT_DIR/$package"

  log_header "▸ $package"

  if [ ! -d "$package_dir" ]; then
    log_warning "Directory not found, skipping: $package_dir"
    return 0
  fi

  if (
    cd "$package_dir"
    flutter pub get
    flutter test --coverage
  ); then
    log_success "$package"
    copy_lcov "$package" "$package_dir/coverage/lcov.info"
    passed_packages+=("$package")
  else
    log_error "$package"
    failed_packages+=("$package")
  fi
}

# run_dart_tests <package>
run_dart_tests() {
  local package="$1"
  local package_dir="$ROOT_DIR/$package"

  log_header "▸ $package (dart)"

  if [ ! -d "$package_dir" ]; then
    log_warning "Directory not found, skipping: $package_dir"
    return 0
  fi

  # Test pass/fail is determined solely by `dart test`.
  if (cd "$package_dir" && dart pub get && dart test --coverage=coverage); then
    log_success "$package"
    passed_packages+=("$package")

    # Coverage formatting is best-effort: activate the package if needed, then
    # convert the raw coverage data to lcov. A failure here does not mark the
    # package as failed.
    dart pub global activate coverage --no-executables 2>/dev/null || true
    (
      cd "$package_dir"
      dart pub global run coverage:format_coverage \
        --lcov \
        --in=coverage \
        --out=coverage/lcov.info \
        --packages=.dart_tool/package_config.json \
        --report-on=lib/src
    ) && copy_lcov "$package" "$package_dir/coverage/lcov.info" \
      || log_warning "Coverage formatting skipped for $package (run: dart pub global activate coverage)"
  else
    log_error "$package"
    failed_packages+=("$package")
  fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
log_header "Running unit tests for all packages"
echo "Root: $ROOT_DIR"

for package in "${FLUTTER_PACKAGES[@]}"; do
  run_flutter_tests "$package"
done

run_dart_tests "$DART_PACKAGE"

# ---------------------------------------------------------------------------
# Merge coverage reports
# ---------------------------------------------------------------------------
log_header "Merging coverage reports"

lcov_args=()
for f in "$COVERAGE_DIR"/*.lcov.info; do
  [ -f "$f" ] && lcov_args+=("-a" "$f")
done

HTML_REPORT_DIR="$COVERAGE_DIR/html"

if [ ${#lcov_args[@]} -eq 0 ]; then
  log_warning "No coverage files found to merge."
elif command -v lcov &>/dev/null && command -v genhtml &>/dev/null; then
  lcov "${lcov_args[@]}" -o "$MERGED_LCOV" 2>/dev/null
  lcov --remove "$MERGED_LCOV" '*/wrappers/*' -o "$MERGED_LCOV" 2>/dev/null
  log_success "Merged lcov report → coverage/lcov.info (wrappers excluded)"

  if genhtml "$MERGED_LCOV" \
       --output-directory "$HTML_REPORT_DIR" \
       --prefix "$ROOT_DIR" \
       --title "opus_flutter – Unit Test Coverage" \
       --legend \
       --ignore-errors source; then
    log_success "HTML report → coverage/html/index.html"
  else
    log_warning "genhtml exited with errors — HTML report may be incomplete."
  fi

  echo ""
  lcov --summary "$MERGED_LCOV" 2>/dev/null || true
else
  log_warning "'lcov' / 'genhtml' not found on PATH — skipping HTML report."
  log_warning "Install them with:  brew install lcov"
  log_warning "Individual lcov files are available in coverage/"
fi

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
    echo -e "  ${GREEN}✓${NC} $pkg"
  done
fi

if [ ${#failed_packages[@]} -gt 0 ]; then
  echo ""
  echo -e "${RED}Failed (${#failed_packages[@]}):${NC}"
  for pkg in "${failed_packages[@]}"; do
    echo -e "  ${RED}✗${NC} $pkg"
  done
  echo ""
  exit 1
fi

echo ""
echo -e "${GREEN}${BOLD}All tests passed!${NC}"
