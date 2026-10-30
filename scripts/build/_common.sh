#!/usr/bin/env bash
# Shared helpers for build scripts. Sourced, not executed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC2034  # used by the scripts that source this file
AOSP_DIR="${ALMUS_AOSP_DIR:-$HOME/aosp}"
die() { echo "ERROR: $*" >&2; exit 1; }
# Fail-closed guard: these scripts download ~250 GB and run for hours.
require_enabled() {
  [ "${ALMUS_ALLOW_FULL_BUILD:-no}" = "yes" ] || die "refusing to run: set ALMUS_ALLOW_FULL_BUILD=yes (only build-aosp.yml does this, after manual approval)"
}
aosp_branch() {
  local b; b="$(tr -d '[:space:]' < "$ROOT/build/AOSP_VERSION")"
  [ -n "$b" ] && [ "$b" != "UNPINNED" ] || die "build/AOSP_VERSION is UNPINNED; pin a branch/tag first (Phase 3)"
  echo "$b"
}
