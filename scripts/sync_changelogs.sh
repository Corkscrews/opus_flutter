#!/usr/bin/env bash
#
# sync_changelogs.sh
#
# Copies opus_dart/CHANGELOG.md to every package in the monorepo so all
# changelogs stay in sync.
#
# Usage:
#   ./scripts/sync_changelogs.sh

set -euo pipefail

# shellcheck source=scripts/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SOURCE="$ROOT_DIR/$DART_PACKAGE/CHANGELOG.md"

if [ ! -f "$SOURCE" ]; then
  log_error "Source changelog not found: $SOURCE"
  exit 1
fi

echo -e "${BOLD}Sync changelogs — $(date '+%Y-%m-%d %H:%M')${NC}"
echo "Source: $SOURCE"

for package in "${FLUTTER_PACKAGES[@]}"; do
  target="$ROOT_DIR/$package/CHANGELOG.md"

  if [ ! -d "$ROOT_DIR/$package" ]; then
    log_warning "Directory not found, skipping: $package"
    continue
  fi

  cp "$SOURCE" "$target"
  log_ok "$package"
done

echo ""
echo -e "${GREEN}${BOLD}All changelogs synced!${NC}"
