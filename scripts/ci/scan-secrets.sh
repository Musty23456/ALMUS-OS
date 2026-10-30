#!/usr/bin/env bash
# scripts/ci/scan-secrets.sh — cheap tripwire, NOT a substitute for GitHub secret scanning.
# Fails on: tracked key/keystore/image files, and common credential patterns in tracked text.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
bad=0
if git ls-files | grep -Ei '\.(pk8|pem|p12|pfx|jks|keystore|key|img|apk|aab|zip|tar\.gz|tgz)$' | grep -v '^docs/templates/' ; then
  echo "ERROR: key/keystore/binary-image files must not be committed (see docs/SECURITY.md)"; bad=1
fi
PATTERN='(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,})'
if git grep -nIE "$PATTERN" -- . ':(exclude)scripts/ci/scan-secrets.sh'; then
  echo "ERROR: possible credential committed"; bad=1
fi
[ "$bad" -eq 0 ] && echo "scan-secrets: nothing suspicious found"
exit "$bad"
