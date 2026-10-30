#!/usr/bin/env bash
# scripts/ci/check-aosp-deps.sh
# Reports which host packages/tools listed in the AOSP "Set up for AOSP development"
# docs are present on THIS machine. Package names come from that page; some may be
# named differently on newer Ubuntu releases, so MISSING is a prompt to look, not proof.
# Usage: check-aosp-deps.sh [--strict]
set -uo pipefail
STRICT=0; [ "${1:-}" = "--strict" ] && STRICT=1
OUT_DIR="${PROBE_OUT_DIR:-probe-out}"; mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/deps.txt"; : > "$OUT"
missing=0
say() { echo "$*" | tee -a "$OUT"; }

say "== AOSP host dependency check $(date -u +%FT%TZ) =="
for p in git-core gnupg flex bison build-essential zip curl zlib1g-dev \
         libc6-dev-i386 x11proto-core-dev libx11-dev lib32z1-dev \
         libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig \
         python3 repo rsync; do
  if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed"; then
    say "[OK]      pkg $p"
  else say "[MISSING] pkg $p"; missing=1; fi
done
for c in git python3 curl; do
  if command -v "$c" >/dev/null 2>&1; then say "[OK]      cmd $c ($("$c" --version 2>&1 | head -1))"
  else say "[MISSING] cmd $c"; missing=1; fi
done
# ccache and adb are optional for the initial host check.
for c in ccache adb; do
  if command -v "$c" >/dev/null 2>&1; then say "[OK]      optional $c"; else say "[ABSENT]  optional $c"; fi
done
say "deps_summary: $([ "$missing" -eq 0 ] && echo ALL_LISTED_PACKAGES_PRESENT || echo SOME_MISSING)"
[ "$STRICT" -eq 1 ] && exit "$missing"
exit 0
