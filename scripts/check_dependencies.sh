#!/usr/bin/env bash
#
# check_dependencies.sh
#
# For every package in the monorepo:
#   - Reports outdated dependencies via `pub outdated`
#   - Checks pub.dev for discontinued / abandoned packages
#
# Usage:
#   ./scripts/check_dependencies.sh
#
# Requirements:
#   - flutter (stable channel)
#   - dart (bundled with flutter)
#   - curl   (optional, for pub.dev discontinued-package checks)
#   - python3 (optional, for JSON parsing of pub.dev API responses)

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
log_ok()      { echo -e "${GREEN}[ OK ]${NC}  $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[DEAD]${NC}  $1"; }
log_header()  { echo -e "\n${BOLD}$1${NC}"; }

# ---------------------------------------------------------------------------
# Configuration
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

ALL_PACKAGES=("${FLUTTER_PACKAGES[@]}" "$DART_PACKAGE")

# ---------------------------------------------------------------------------
# Tracking
# ---------------------------------------------------------------------------
packages_with_outdated=()
discontinued_findings=()   # "<dep> (in <package>) [→ replaced by: <x>]"

has_curl=false
has_python=false
command -v curl   &>/dev/null && has_curl=true
command -v python3 &>/dev/null && has_python=true

# ---------------------------------------------------------------------------
# pub outdated
# ---------------------------------------------------------------------------

# run_outdated <package> <dart|flutter>
run_outdated() {
  local package="$1"
  local tool="${2:-flutter}"
  local package_dir="$ROOT_DIR/$package"

  log_header "▸ $package"

  if [ ! -d "$package_dir" ]; then
    log_warning "Directory not found, skipping."
    return 0
  fi

  # Resolve dependencies quietly so the outdated output is uncluttered.
  ( cd "$package_dir" && $tool pub get 2>&1 ) | grep -v "^Resolving\|^Downloading\|^Got dep\|^Changed\|packages have newer\|Try \`" || true

  local output
  output=$(cd "$package_dir" && $tool pub outdated 2>&1) || true

  if echo "$output" | grep -qiE "^Found no outdated|^No dependencies"; then
    log_ok "All dependencies are up-to-date."
  else
    echo "$output"
    packages_with_outdated+=("$package")
  fi
}

# ---------------------------------------------------------------------------
# pub.dev discontinued-package check
# ---------------------------------------------------------------------------

# check_pubdev_package <dep_name> <context_package>
# Returns 1 and appends to discontinued_findings if the package is discontinued.
check_pubdev_package() {
  local dep="$1"
  local ctx="$2"

  local response
  response=$(curl -sf --max-time 10 "https://pub.dev/api/packages/$dep" 2>/dev/null) || return 0

  local is_discontinued replaced_by
  read -r is_discontinued replaced_by < <(python3 - <<EOF
import json, sys
try:
    d = json.loads("""$response""")
    disc = d.get("isDiscontinued", False)
    repl = d.get("replacedBy") or ""
    print("true" if disc else "false", repl)
except Exception:
    print("false", "")
EOF
  ) 2>/dev/null || return 0

  if [ "$is_discontinued" = "true" ]; then
    if [ -n "$replaced_by" ]; then
      discontinued_findings+=("$dep  (in $ctx)  →  replaced by: $replaced_by")
    else
      discontinued_findings+=("$dep  (in $ctx)  →  no replacement listed")
    fi
    return 1
  fi
}

# extract_deps <pubspec_path>
# Prints one pub.dev package name per line (skips sdk / path deps).
extract_deps() {
  local pubspec="$1"
  python3 - <<EOF 2>/dev/null
import sys

with open("$pubspec") as f:
    lines = f.readlines()

in_deps = False
base_indent = -1
seen = set()

for line in lines:
    stripped = line.lstrip()
    indent = len(line) - len(stripped)
    stripped = stripped.rstrip()

    # Start of a dep block
    if stripped in ("dependencies:", "dev_dependencies:", "dependency_overrides:"):
        in_deps = True
        base_indent = indent
        continue

    if not in_deps:
        continue

    # Leaving the dep block (new top-level key)
    if stripped and indent <= base_indent and not stripped.startswith("#"):
        in_deps = False
        continue

    # A dependency entry looks like "  package_name:" at base_indent + 2
    if stripped.endswith(":") and indent == base_indent + 2:
        name = stripped[:-1]
        # Skip SDK pseudo-packages and already-seen
        if name not in ("flutter", "dart") and name not in seen:
            seen.add(name)
            print(name)
EOF
}

# check_abandoned <package>
check_abandoned() {
  local package="$1"
  local pubspec="$ROOT_DIR/$package/pubspec.yaml"

  [ -f "$pubspec" ] || return 0

  if ! $has_curl || ! $has_python; then return 0; fi

  local deps
  deps=$(extract_deps "$pubspec") || return 0
  [ -z "$deps" ] && return 0

  log_info "Checking $package dependencies on pub.dev..."

  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    check_pubdev_package "$dep" "$package" || true
  done <<< "$deps"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo -e "${BOLD}Dependency report — $(date '+%Y-%m-%d %H:%M')${NC}"
echo "Root: $ROOT_DIR"

if ! $has_curl || ! $has_python; then
  log_warning "curl and python3 are both required for discontinued-package checks."
  log_warning "One or both were not found — that section will be skipped."
fi

# ── Outdated ──────────────────────────────────────────────────────────────
log_header "━━━ Outdated dependencies ━━━"

for package in "${FLUTTER_PACKAGES[@]}"; do
  run_outdated "$package" flutter
done

run_outdated "$DART_PACKAGE" dart

# ── Discontinued ──────────────────────────────────────────────────────────
log_header "━━━ Discontinued / abandoned packages (pub.dev) ━━━"

if $has_curl && $has_python; then
  for package in "${ALL_PACKAGES[@]}"; do
    check_abandoned "$package"
  done
else
  log_warning "Skipped (requires curl + python3)."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo -e "${BOLD}Summary${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"

if [ ${#packages_with_outdated[@]} -eq 0 ]; then
  echo -e "${GREEN}✓  All dependencies are up-to-date.${NC}"
else
  echo -e "${YELLOW}Packages with outdated dependencies (${#packages_with_outdated[@]}):${NC}"
  for pkg in "${packages_with_outdated[@]}"; do
    echo -e "  ${YELLOW}⚠${NC}  $pkg"
  done
fi

echo ""

if [ ${#discontinued_findings[@]} -eq 0 ]; then
  if $has_curl && $has_python; then
    echo -e "${GREEN}✓  No discontinued packages found.${NC}"
  else
    echo -e "${YELLOW}⚠  Discontinued-package check skipped (install curl + python3).${NC}"
  fi
else
  echo -e "${RED}Discontinued packages found (${#discontinued_findings[@]}):${NC}"
  for entry in "${discontinued_findings[@]}"; do
    echo -e "  ${RED}✗${NC}  $entry"
  done
fi

echo ""

# Exit 1 only if discontinued packages were found (outdated is informational).
[ ${#discontinued_findings[@]} -eq 0 ]
