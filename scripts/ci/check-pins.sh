#!/usr/bin/env bash
# scripts/ci/check-pins.sh — fail if any third-party action is not pinned to a 40-hex commit SHA.
# Local actions (./...) are exempt. docker:// references must use @sha256:.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
bad=0
while IFS= read -r hit; do
  ref=$(echo "$hit" | sed -E 's/^[^:]+:[0-9]+:[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//; s/[[:space:]]+#.*$//; s/["'"'"']//g')
  case "$ref" in
    ./*) continue ;;
    docker://*@sha256:*) continue ;;
    docker://*) echo "UNPINNED docker ref: $hit"; bad=1; continue ;;
  esac
  if ! echo "$ref" | grep -Eq '@[0-9a-f]{40}$'; then echo "UNPINNED action: $hit"; bad=1; fi
done < <(grep -rnE '^[[:space:]]*-?[[:space:]]*uses:' .github --include='*.yml' --include='*.yaml' || true)
[ "$bad" -eq 0 ] && echo "check-pins: all third-party actions pinned to full SHAs"
exit "$bad"
