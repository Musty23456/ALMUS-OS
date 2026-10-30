#!/usr/bin/env bash
# TEMPLATE — NOT EXECUTED IN PHASE 2. Usage: build.sh <lunch-target>
# shellcheck source=_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
require_enabled
TARGET="${1:-}"; [ -n "$TARGET" ] || die "usage: build.sh <lunch-target>"
grep -qxF "$TARGET" <(grep -v '^[[:space:]]*#' "$ROOT/build/targets.conf" | sed 's/[[:space:]]*$//') \
  || die "target '$TARGET' is not listed in build/targets.conf"
cd "$AOSP_DIR"
if [ "${ALMUS_USE_CCACHE:-0}" = "1" ]; then export USE_CCACHE=1 CCACHE_EXEC="$(command -v ccache)"; fi
set +u   # envsetup/lunch reference unset variables
# shellcheck disable=SC1091
source build/envsetup.sh
lunch "$TARGET"
m -j"$(nproc)"
echo "build complete: $TARGET"
