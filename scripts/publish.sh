#!/usr/bin/env bash
#
# publish.sh
#
# Publishes all packages to pub.dev in dependency order (three tiers).
# By default runs in dry-run mode; pass --publish to actually push to pub.dev.
#
# Usage:
#   ./scripts/publish.sh              # dry run (validate only)
#   ./scripts/publish.sh --publish    # publish for real
#   ./scripts/publish.sh --wait 60    # customise the inter-tier wait (default 120s)
#
# Requirements:
#   - flutter (stable channel) with dart bundled

set -euo pipefail

# shellcheck source=scripts/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

DRY_RUN=true
WAIT_SECONDS=120

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)  DRY_RUN=false;        shift ;;
    --dry-run)  DRY_RUN=true;         shift ;;
    --wait)     WAIT_SECONDS="$2";    shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run | --publish] [--wait <seconds>]"
      exit 0 ;;
    *)
      echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Tier definitions (publish order mirrors dependency graph)
# ---------------------------------------------------------------------------
TIER_1_PACKAGES=("opus_dart:dart" "opus_flutter_platform_interface:flutter")

TIER_2_PACKAGES=(
  "opus_flutter_android:flutter"
  "opus_flutter_ios:flutter"
  "opus_flutter_linux:flutter"
  "opus_flutter_macos:flutter"
  "opus_flutter_windows:flutter"
  "opus_flutter_web:flutter"
)

TIER_3_PACKAGES=("opus_flutter:flutter")

# ---------------------------------------------------------------------------
# Cleanup — restore pubspec.yaml files modified by prepare_publish.dart
# ---------------------------------------------------------------------------
modified_pubspecs=()

cleanup() {
  for f in "${modified_pubspecs[@]}"; do
    if [ -f "${f}.bak" ]; then
      mv "${f}.bak" "$f"
    fi
  done
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

prepare_package() {
  local dir="$1"
  local pubspec="$ROOT_DIR/$dir/pubspec.yaml"

  cp "$pubspec" "${pubspec}.bak"
  modified_pubspecs+=("$pubspec")

  ( cd "$ROOT_DIR" && dart run scripts/prepare_publish.dart "$dir" )
}

publish_package() {
  local entry="$1"
  local dir="${entry%%:*}"
  local tool="${entry##*:}"

  log_info "Publishing ${BOLD}$dir${NC} ($tool pub publish)…"
  prepare_package "$dir"

  if $DRY_RUN; then
    ( cd "$ROOT_DIR/$dir" && $tool pub publish --dry-run )
  else
    ( cd "$ROOT_DIR/$dir" && $tool pub publish --force )
  fi

  log_ok "$dir"
}

publish_tier() {
  local tier_name="$1"; shift
  local packages=("$@")

  log_header "━━━ $tier_name ━━━"
  for entry in "${packages[@]}"; do
    publish_package "$entry"
  done
}

wait_for_indexing() {
  if ! $DRY_RUN; then
    log_info "Waiting ${WAIT_SECONDS}s for pub.dev indexing…"
    sleep "$WAIT_SECONDS"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if $DRY_RUN; then
  echo -e "${BOLD}Publish (dry run)${NC}"
else
  echo -e "${BOLD}Publishing to pub.dev${NC}"
fi

publish_tier "Tier 1 — core packages" "${TIER_1_PACKAGES[@]}"
wait_for_indexing

publish_tier "Tier 2 — platform packages" "${TIER_2_PACKAGES[@]}"
wait_for_indexing

publish_tier "Tier 3 — app-facing package" "${TIER_3_PACKAGES[@]}"

echo ""
if $DRY_RUN; then
  log_success "Dry run complete — all packages validated."
else
  log_success "All packages published to pub.dev."
fi
