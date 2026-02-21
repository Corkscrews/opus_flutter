#!/usr/bin/env bash
#
# format.sh
#
# Checks that all Dart code in the monorepo is formatted correctly.
# Exits with a non-zero code if any file needs formatting.
#
# Usage:
#   ./scripts/format.sh
#
# Requirements:
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
# Main
# ---------------------------------------------------------------------------
echo -e "${BOLD}Format check — $(date '+%Y-%m-%d %H:%M')${NC}"
echo "Root: $ROOT_DIR"

log_header "━━━ Checking formatting ━━━"

for package in "$DART_PACKAGE" "${FLUTTER_PACKAGES[@]}"; do
  local_dir="$ROOT_DIR/$package"

  if [ ! -d "$local_dir" ]; then
    log_warning "Directory not found, skipping: $local_dir"
    continue
  fi

  log_header "▸ $package"

  # Resolve packages first so the formatter can read analysis_options.yaml
  # (needed for page_width and other formatter settings in Dart 3.7+).
  (cd "$local_dir" && flutter pub get --quiet 2>/dev/null) || \
  (cd "$local_dir" && dart pub get --quiet 2>/dev/null) || true

  if dart format --set-exit-if-changed "$local_dir/"; then
    log_success "$package"
    passed_packages+=("$package")
  else
    log_error "$package"
    failed_packages+=("$package")
  fi
done

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
echo -e "${GREEN}${BOLD}All packages are properly formatted!${NC}"
