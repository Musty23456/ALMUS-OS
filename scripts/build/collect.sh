#!/usr/bin/env bash
# TEMPLATE — NOT EXECUTED IN PHASE 2. Gathers images into ./out-artifacts with SHA256SUMS.
# shellcheck source=_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
require_enabled
DEST="${1:-$ROOT/out-artifacts}"; mkdir -p "$DEST"
PRODUCT_OUT="$(ls -d "$AOSP_DIR"/out/target/product/*/ 2>/dev/null | head -1 || true)"
[ -n "$PRODUCT_OUT" ] || die "no product output under $AOSP_DIR/out/target/product"
cp -v "$PRODUCT_OUT"/*.img "$DEST"/ 2>/dev/null || die "no .img files found"
cp -v "$PRODUCT_OUT"/android-info.txt "$DEST"/ 2>/dev/null || true
# Cuttlefish host package path/target name: UNVERIFIED, resolve in Phase 3.
for h in "$AOSP_DIR"/out/host/linux-x86/cvd-host_package.tar.gz; do [ -f "$h" ] && cp -v "$h" "$DEST"/; done
(cd "$DEST" && sha256sum ./* > SHA256SUMS)
du -sh "$DEST"
