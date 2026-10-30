#!/usr/bin/env bash
# TEMPLATE — NOT EXECUTED IN PHASE 2. Syncs the pinned AOSP branch and overlays ALMUS files.
# shellcheck source=_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
require_enabled
BRANCH="$(aosp_branch)"

mkdir -p "$AOSP_DIR" "$HOME/.bin"
if ! command -v repo >/dev/null 2>&1; then
  curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/.bin/repo"
  chmod a+rx "$HOME/.bin/repo"; export PATH="$HOME/.bin:$PATH"
fi
cd "$AOSP_DIR"
# REPO_INIT_EXTRA may hold e.g. partial-clone flags once evaluated (UNVERIFIED benefit/size).
# shellcheck disable=SC2086
repo init -u https://android.googlesource.com/platform/manifest -b "$BRANCH" ${REPO_INIT_EXTRA:-}
mkdir -p .repo/local_manifests
cp "$ROOT"/build/manifests/*.xml .repo/local_manifests/ 2>/dev/null || true   # only real .xml, not *.template
repo sync -c -j"$(nproc)" --no-tags --no-clone-bundle --fail-fast

# Overlay ALMUS-owned trees (device/, vendor/). Patch series for frameworks/ packages/ system/ come in a later phase.
for d in device/almus vendor/almus; do
  if [ -d "$ROOT/$d" ]; then mkdir -p "$AOSP_DIR/$d"; rsync -a --delete "$ROOT/$d/" "$AOSP_DIR/$d/"; fi
done
echo "sync complete: $BRANCH"
