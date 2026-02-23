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

# shellcheck source=scripts/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

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
    dart run build_runner build --delete-conflicting-outputs
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
